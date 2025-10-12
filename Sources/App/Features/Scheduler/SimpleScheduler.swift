import Vapor
import Foundation
import Dispatch

/// Простой планировщик без зависимости от Queues
final class SimpleScheduler {
    private let app: Application
    private var timers: [DispatchSourceTimer] = []
    
    init(app: Application) {
        self.app = app
    }
    
    /// Запускает автоматическую генерацию постов по расписанию
    func startPostSchedule() {
        let schedules = ScheduleConfig.defaultSchedules
        
        for schedule in schedules {
            scheduleDaily(at: schedule.hour, minute: schedule.minute) { [weak self] in
                guard let self = self else { return }
                
                Task {
                    await self.generateAndPublishPost(
                        templateType: schedule.templateType,
                        topic: schedule.topic
                    )
                }
            }
            
            app.logger.info("📅 Настроено расписание: \(schedule.timeString) - \(schedule.templateType.rawValue)")
        }
    }
    
    /// Планирует ежедневное выполнение в указанное время
    private func scheduleDaily(at hour: Int, minute: Int, action: @escaping () -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        
        // Вычисляем время до следующего запуска
        let nextRun = calculateNextRun(hour: hour, minute: minute)
        let interval = nextRun.timeIntervalSinceNow
        
        // Запускаем таймер
        timer.schedule(
            deadline: .now() + interval,
            repeating: .seconds(86400) // 24 часа
        )
        
        timer.setEventHandler {
            action()
        }
        
        timer.resume()
        timers.append(timer)
        
        app.logger.info("⏰ Следующий запуск в \(String(format: "%02d:%02d", hour, minute)) через \(Int(interval/60)) минут")
    }
    
    /// Вычисляет время следующего запуска
    private func calculateNextRun(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let scheduledTime = calendar.date(from: components) else {
            return now.addingTimeInterval(3600) // Запас на час
        }
        
        // Если время уже прошло сегодня, берём завтра
        if scheduledTime <= now {
            return calendar.date(byAdding: .day, value: 1, to: scheduledTime) ?? scheduledTime
        }
        
        return scheduledTime
    }
    
    /// Генерирует и публикует пост
    private func generateAndPublishPost(templateType: PostCategory, topic: String) async {
        app.logger.info("🕐 Автоматическая генерация поста: \(topic)")
        
        do {
            // Создаём сервисы
            let aiClient = AnthropicClient(client: app.client, logger: app.logger)
            let validator = ContentValidator()
            let contentGenerator = ContentGeneratorService(
                aiClient: aiClient,
                validator: validator,
                logger: app.logger
            )
            let notifier = TelegramNotifier(client: app.client, logger: app.logger)
            
            // ВАЖНО: используем TelegramChannelPublisher для РЕАЛЬНОЙ публикации в канал
            let publisher = TelegramChannelPublisher(
                client: app.client,
                logger: app.logger,
                contentGenerator: contentGenerator
            )
            
            // Создаём запрос
            let request = GenerationRequest(
                templateType: templateType,
                topic: topic,
                destinations: selectDestinations(for: templateType),
                priceData: nil,
                trendData: nil
            )
            
            // Генерируем пост
            let response = try await contentGenerator.generatePost(
                request: request,
                db: app.db
            )
            
            app.logger.info("✅ Пост сгенерирован: \(response.postId)")
            
            // Публикуем пост
            guard let post = try await ZenPostModel.find(response.postId, on: app.db) else {
                throw Abort(.notFound, reason: "Post not found")
            }
            
            let publishResult = try await publisher.publish(post: post, db: app.db)
            
            if publishResult.success {
                app.logger.info("✅ Пост опубликован в Telegram канал: \(publishResult.publishedURL ?? "N/A")")
                
                // Уведомляем админа об успехе
                try? await notifier.sendNotification(
                    message: """
                    ✅ <b>Автопост опубликован в канал!</b>
                    
                    📝 <b>\(response.title)</b>
                    
                    📊 <b>Детали:</b>
                    • Короткий пост: \(response.shortPost.count) символов
                    • Полный пост: \(response.fullPost.count) символов
                    • Изображений: \(response.imageURLs.count)
                    
                    🔗 <b>Канал:</b> \(AppConfig.telegramChannelId)
                    📖 <b>Telegraph:</b> будет создан при публикации
                    
                    🕐 \(Date())
                    """
                )
            } else {
                app.logger.error("❌ Ошибка публикации: \(publishResult.errorMessage ?? "Unknown")")
                try? await notifier.sendError(error: "Ошибка автопубликации: \(publishResult.errorMessage ?? "Unknown")")
            }
            
        } catch {
            app.logger.error("❌ Ошибка автогенерации: \(error)")
            
            let notifier = TelegramNotifier(client: app.client, logger: app.logger)
            try? await notifier.sendError(error: "Ошибка автопубликации: \(error.localizedDescription)")
        }
    }
    
    /// Выбирает направления для поста
    private func selectDestinations(for type: PostCategory) -> [String] {
        let allDestinations = [
            "Турция", "Египет", "ОАЭ", "Таиланд", "Вьетнам",
            "Грузия", "Армения", "Узбекистан", "Казахстан",
            "Индия", "Шри-Ланка", "Мальдивы", "Бали", "Китай"
        ]
        
        switch type {
        case .comparison:
            return Array(allDestinations.shuffled().prefix(2))
        case .budget, .trending:
            return Array(allDestinations.shuffled().prefix(5))
        default:
            return Array(allDestinations.shuffled().prefix(1))
        }
    }
    
    /// Останавливает все таймеры
    func stop() {
        timers.forEach { $0.cancel() }
        timers.removeAll()
        app.logger.info("⏹ Планировщик остановлен")
    }
}
