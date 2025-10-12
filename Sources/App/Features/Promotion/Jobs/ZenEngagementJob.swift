import Vapor
import Fluent
import Queues

/// Джоба для автоматического взаимодействия с Яндекс Дзеном
struct ZenEngagementJob: AsyncScheduledJob {
    let engagementService: ZenEngagementServiceProtocol
    let logger: Logger
    
    func run(context: QueueContext) async throws {
        let logger = context.logger
        logger.info("🎯 Запуск автоматического взаимодействия с Дзеном")
        
        // Ключевые слова для поиска постов
        let keywords = [
            "путешествия", "билеты", "туры", "отдых",
            "бюджетные направления", "виза", "отели",
            "куда поехать", "дешевые авиабилеты"
        ]
        
        do {
            // 1. Ищем посты для комментирования
            let posts = try await engagementService.findPostsForCommenting(keywords: keywords)
            logger.info("📝 Найдено \(posts.count) постов для взаимодействия")
            
            // 2. Обрабатываем каждый пост
            for post in posts.prefix(3) { // Ограничиваем 3 постами за раз
                logger.info("🔍 Анализирую пост: \(post.title)")
                
                // 3. Ищем вопросы в комментариях
                let questions = try await engagementService.findQuestionsInComments(postUrl: post.url)
                logger.info("❓ Найдено \(questions.count) вопросов")
                
                // 4. Отвечаем на неотвеченные вопросы
                let unansweredQuestions = questions.filter { !$0.isAnswered }
                
                for question in unansweredQuestions.prefix(2) { // Максимум 2 ответа на пост
                    logger.info("💬 Отвечаю на вопрос: \(question.text.prefix(50))...")
                    
                    // 5. Генерируем умный ответ
                    let response = try await engagementService.generateSmartResponse(to: question)
                    
                    // 6. Отправляем комментарий
                    let success = try await engagementService.postComment(to: post.url, comment: response)
                    
                    if success {
                        logger.info("✅ Ответ отправлен успешно")
                        
                        // Пауза между ответами (избегаем спама)
                        try await Task.sleep(nanoseconds: 30_000_000_000) // 30 секунд
                    } else {
                        logger.warning("⚠️ Не удалось отправить ответ")
                    }
                }
                
                // Пауза между постами
                try await Task.sleep(nanoseconds: 60_000_000_000) // 1 минута
            }
            
            // 7. Анализируем эффективность
            let stats = try await engagementService.analyzeEngagement()
            logger.info("📊 Статистика: \(stats.totalComments) комментариев, \(stats.newSubscribers) новых подписчиков")
            
        } catch {
            logger.error("❌ Ошибка взаимодействия с Дзеном: \(error)")
        }
    }
}
