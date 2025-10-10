import Vapor
import Fluent
import Queues

struct DailyPostJob: AsyncScheduledJob {
    let contentGenerator: ContentGeneratorServiceProtocol
    let publisher: ZenPublisherProtocol
    let notifier: TelegramNotifierProtocol
    
    func run(context: QueueContext) async throws {
        let logger = context.logger
        logger.info("🕐 Запуск генерации поста по расписанию")
        
        // Определяем текущее расписание
        guard let schedule = ScheduleConfig.getCurrentSchedule() else {
            logger.warning("Нет активного расписания для текущего времени")
            return
        }
        
        logger.info("📝 Генерируем пост типа: \(schedule.templateType.rawValue)")
        
        do {
            // 1. Создаём запрос на генерацию
            let request = GenerationRequest(
                templateType: schedule.templateType,
                topic: schedule.topic,
                destinations: selectDestinations(for: schedule.templateType),
                priceData: nil,
                trendData: nil
            )
            
            // 2. Генерируем пост
            let response = try await contentGenerator.generatePost(
                request: request,
                db: context.application.db
            )
            
            logger.info("✅ Пост сгенерирован: \(response.postId)")
            
            // 3. Публикуем пост
            guard let post = try await ZenPostModel.find(response.postId, on: context.application.db) else {
                throw Abort(.notFound, reason: "Post not found")
            }
            
            let publishResult = try await publisher.publish(post: post, db: context.application.db)
            
            if publishResult.success {
                logger.info("✅ Пост опубликован: \(publishResult.zenArticleId ?? "N/A")")
            } else {
                logger.error("❌ Ошибка публикации: \(publishResult.errorMessage ?? "Unknown")")
            }
            
        } catch {
            logger.error("❌ Ошибка генерации поста: \(error)")
            try? await notifier.sendError(error: "Ошибка генерации поста: \(error.localizedDescription)")
        }
    }
    
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
}

