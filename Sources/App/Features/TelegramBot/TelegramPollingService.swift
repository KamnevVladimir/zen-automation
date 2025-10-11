import Vapor
import Foundation

/// Сервис для получения обновлений от Telegram через Long Polling
final class TelegramPollingService {
    private let app: Application
    private let client: Client
    private let botToken: String
    private let controller: TelegramBotController
    private var offset: Int = 0
    private var isRunning = false
    
    init(app: Application, controller: TelegramBotController) {
        self.app = app
        self.client = app.client
        self.botToken = AppConfig.telegramToken
        self.controller = controller
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        app.logger.info("🚀 Запуск Telegram Long Polling...")
        
        Task {
            // Перед стартом: удаляем webhook и очищаем pending updates
            await initializePolling()
            await pollForUpdates()
        }
    }
    
    /// Инициализация polling: удаление webhook и очистка updates
    private func initializePolling() async {
        do {
            // 1. Удаляем webhook (если был установлен)
            app.logger.info("🔧 Удаляю webhook (если был)...")
            try await deleteWebhook()
            
            // 2. Очищаем pending updates (решает 409 Conflict)
            app.logger.info("🔧 Очищаю pending updates...")
            let pendingUpdates = try await getUpdates()
            if !pendingUpdates.isEmpty {
                offset = pendingUpdates.last!.updateId + 1
                app.logger.info("✅ Очищено \(pendingUpdates.count) pending updates")
            }
            
            app.logger.info("✅ Polling инициализирован успешно")
        } catch {
            app.logger.error("❌ Ошибка инициализации polling: \(error)")
        }
    }
    
    /// Удаляет webhook
    private func deleteWebhook() async throws {
        let url = URI(string: "https://api.telegram.org/bot\(botToken)/deleteWebhook")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = ["drop_pending_updates": true]
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            app.logger.warning("⚠️ Не удалось удалить webhook: \(response.status)")
            return
        }
        
        app.logger.info("✅ Webhook удалён")
    }
    
    func stop() {
        isRunning = false
        app.logger.info("⏹️ Остановка Telegram Long Polling")
    }
    
    private func pollForUpdates() async {
        while isRunning {
            do {
                let updates = try await getUpdates()
                
                for update in updates {
                    // Обновляем offset для следующего запроса
                    offset = max(offset, update.updateId + 1)
                    
                    // Обрабатываем каждое обновление
                    await processUpdate(update)
                }
                
                // Небольшая пауза между запросами
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
                
            } catch {
                // Более мягкая обработка ошибок - не падаем, а логируем и продолжаем
                if isRunning {  // Только если не идет shutdown
                    app.logger.warning("⚠️ Ошибка polling (продолжаем работу): \(error)")
                    // Пауза при ошибке
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд
                } else {
                    app.logger.info("ℹ️ Polling остановлен во время shutdown")
                    break
                }
            }
        }
    }
    
    private func getUpdates() async throws -> [TelegramUpdate] {
        let url = URI(string: "https://api.telegram.org/bot\(botToken)/getUpdates")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "offset": offset,
            "limit": 100,
            "timeout": 30 // Long polling timeout
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Telegram API error: \(response.status)")
        }
        
        struct TelegramResponse: Content {
            let ok: Bool
            let result: [TelegramUpdate]
        }
        
        let telegramResponse = try response.content.decode(TelegramResponse.self)
        
        guard telegramResponse.ok else {
            throw Abort(.internalServerError, reason: "Telegram API returned error")
        }
        
        return telegramResponse.result
    }
    
    private func processUpdate(_ update: TelegramUpdate) async {
        guard let message = update.message,
              let text = message.text,
              let from = message.from else {
            return
        }
        
        // Проверяем что сообщение от админа
        guard from.id == AppConfig.adminUserId else {
            app.logger.info("⚠️ Игнорирую сообщение от пользователя: \(from.id)")
            return
        }
        
        app.logger.info("📨 Получена команда от админа: \(text)")
        
        // Создаём фейковый Request для контроллера
        let fakeRequest = Request(
            application: app,
            method: .POST,
            url: URI(string: "/fake"),
            on: app.eventLoopGroup.next()
        )
        
        // Передаем все сообщения в контроллер
        await controller.handleMessage(
            text: text,
            userId: from.id,
            chatId: message.chat.id,
            req: fakeRequest
        )
    }
}
