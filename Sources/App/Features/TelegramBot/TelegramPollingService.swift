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
    
    // Глобальный счетчик активных инстансов для защиты от 409 Conflict
    private static var activeInstances: Int = 0
    private static let instanceLock = NSLock()
    
    init(app: Application, controller: TelegramBotController) {
        self.app = app
        self.client = app.client
        self.botToken = AppConfig.telegramToken
        self.controller = controller
    }
    
    func start() {
        guard !isRunning else {
            app.logger.warning("⚠️ Polling уже запущен в этом процессе")
            return
        }
        
        // Проверяем количество активных инстансов
        Self.instanceLock.lock()
        let currentInstances = Self.activeInstances
        Self.activeInstances += 1
        Self.instanceLock.unlock()
        
        if currentInstances > 0 {
            app.logger.warning("⚠️ Обнаружено \(currentInstances + 1) активных инстансов polling!")
            app.logger.warning("⚠️ Это может вызвать 409 Conflict. Проверьте Railway на дублирование процессов.")
        }
        
        isRunning = true
        
        app.logger.info("🚀 Запуск Telegram Long Polling... (инстанс #\(currentInstances + 1))")
        
        Task {
            // Перед стартом: удаляем webhook и очищаем pending updates
            await initializePolling()
            await pollForUpdates()
        }
    }
    
    /// Инициализация polling: удаление webhook
    private func initializePolling() async {
        do {
            // Удаляем webhook чтобы избежать 409 Conflict
            app.logger.info("🔧 Удаляю webhook (для чистого long-polling)...")
            try await deleteWebhook()
            app.logger.info("✅ Polling готов к работе")
        } catch {
            app.logger.warning("⚠️ Не удалось удалить webhook: \(error). Продолжаю...")
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
        guard isRunning else { return }
        
        isRunning = false
        
        // Уменьшаем счетчик активных инстансов
        Self.instanceLock.lock()
        Self.activeInstances = max(0, Self.activeInstances - 1)
        let remaining = Self.activeInstances
        Self.instanceLock.unlock()
        
        app.logger.info("⏹️ Остановка Telegram Long Polling (осталось инстансов: \(remaining))")
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
                    
                    // Проверяем тип ошибки
                    let is409Error = "\(error)".contains("409") || "\(error)".contains("Conflict")
                    
                    if is409Error {
                        app.logger.error("🚨 Обнаружен 409 Conflict! Возможно запущено несколько инстансов.")
                        app.logger.error("💡 Решение: убедитесь что на Railway запущена только одна реплика.")
                        // Увеличенная пауза при 409
                        try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 секунд
                    } else {
                        // Обычная пауза при других ошибках
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд
                    }
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
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            app.logger.error("❌ Telegram getUpdates error!")
            app.logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
            app.logger.error("   Body: \(errorBody)")
            throw Abort(.internalServerError, reason: "Telegram API error: \(response.status) - \(errorBody)")
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
