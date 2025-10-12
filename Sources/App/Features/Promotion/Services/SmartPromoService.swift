import Vapor
import Fluent

/// Умный сервис для промо-активности с анализом наших статей
final class SmartPromoService {
    private let client: Client
    private let logger: Logger
    private let aiClient: AIClientProtocol
    
    init(client: Client, logger: Logger, aiClient: AIClientProtocol) {
        self.client = client
        self.logger = logger
        self.aiClient = aiClient
    }
    
    /// Находит популярные посты в Дзене и генерирует ответы на основе НАШИХ статей
    func findPostsWithSmartResponses(db: Database) async throws -> [PromoSuggestion] {
        logger.info("🔍 Ищу посты в Дзене и анализирую наши статьи...")
        
        // 1. Получаем наши последние опубликованные статьи
        let ourPosts = try await ZenPostModel.query(on: db)
            .filter(\.$status == .published)
            .sort(\.$publishedAt, .descending)
            .limit(10)
            .all()
        
        logger.info("📚 Найдено \(ourPosts.count) наших статей для анализа")
        
        // 2. Примеры популярных вопросов в Дзене (в реальности - через парсинг)
        let exampleQuestions = [
            ZenQuestion(
                postUrl: "https://dzen.ru/media/id/5d9a1b2c3642b600ad8f9e12/kak-poletet-deshevo",
                postTitle: "Как полететь дёшево в 2025 году",
                question: "Подскажите, где искать дешёвые билеты? Какие сервисы используете?",
                category: "билеты"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/media/id/5d9a1b2c3642b600ad8f9e12/viza-v-gruziiu",
                postTitle: "Виза в Грузию для россиян",
                question: "Нужна ли виза в Грузию? Как долго можно там находиться?",
                category: "виза"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/media/id/5d9a1b2c3642b600ad8f9e12/tailand-ili-vetnam",
                postTitle: "Таиланд или Вьетнам - куда лучше?",
                question: "Сколько денег нужно на 2 недели отдыха в Таиланде?",
                category: "бюджет"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/media/id/5d9a1b2c3642b600ad8f9e12/egipet-2025",
                postTitle: "Египет 2025 - всё включено",
                question: "Какие отели в Египте лучшие по соотношению цена/качество?",
                category: "отели"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/media/id/5d9a1b2c3642b600ad8f9e12/uae-dlya-turistov",
                postTitle: "ОАЭ для туристов - гид 2025",
                question: "В какое время года лучше лететь в ОАЭ? Не слишком жарко?",
                category: "погода"
            )
        ]
        
        // 3. Для каждого вопроса находим подходящую НАШУ статью и генерируем ответ
        var suggestions: [PromoSuggestion] = []
        
        for question in exampleQuestions.prefix(3) {
            // Анализируем, какая из наших статей подходит
            let matchingArticle = try await findBestMatchingArticle(
                question: question,
                ourPosts: ourPosts
            )
            
            // Генерируем ответ с упоминанием нашей статьи
            let response = try await generateSmartResponse(
                question: question,
                matchingArticle: matchingArticle
            )
            
            let suggestion = PromoSuggestion(
                postUrl: question.postUrl,
                postTitle: question.postTitle,
                question: question.question,
                suggestedResponse: response.answer,
                ourArticleUrl: matchingArticle?.telegraphUrl,
                ourArticleTitle: matchingArticle?.title,
                relevanceScore: response.relevanceScore
            )
            
            suggestions.append(suggestion)
            
            // Пауза между генерациями
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        }
        
        // Сортируем по релевантности
        return suggestions.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    /// Находит наиболее подходящую нашу статью для ответа на вопрос
    private func findBestMatchingArticle(
        question: ZenQuestion,
        ourPosts: [ZenPostModel]
    ) async throws -> MatchingArticle? {
        
        // Создаём список наших статей для анализа
        let articlesContext = ourPosts.map { post in
            """
            Статья: \(post.title)
            Тип: \(post.templateType)
            Краткое содержание: \(post.shortPost?.prefix(200) ?? "")
            """
        }.joined(separator: "\n\n")
        
        let analysisPrompt = """
        Проанализируй вопрос пользователя и найди НАИБОЛЕЕ ПОДХОДЯЩУЮ статью из списка для ответа.
        
        ВОПРОС: "\(question.question)"
        КАТЕГОРИЯ: \(question.category)
        
        НАШИ СТАТЬИ:
        \(articlesContext)
        
        Ответь СТРОГО в JSON формате:
        {
            "best_match_title": "название самой подходящей статьи",
            "relevance_score": 0.85,
            "reason": "краткое объяснение почему подходит"
        }
        
        Если НИ ОДНА статья не подходит, верни:
        {
            "best_match_title": null,
            "relevance_score": 0.0,
            "reason": "нет релевантной статьи"
        }
        """
        
        let analysisResult = try await aiClient.generateText(
            systemPrompt: "Ты - аналитик контента. Отвечай только в JSON формате.",
            userPrompt: analysisPrompt
        )
        
        // Парсим JSON ответ
        guard let jsonData = analysisResult.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let bestMatchTitle = json["best_match_title"] as? String,
              let relevanceScore = json["relevance_score"] as? Double else {
            logger.warning("⚠️ Не удалось распарсить ответ AI для анализа статей")
            return nil
        }
        
        // Находим статью по названию
        let matchingPost = ourPosts.first { post in
            post.title.lowercased().contains(bestMatchTitle.lowercased()) ||
            bestMatchTitle.lowercased().contains(post.title.lowercased())
        }
        
        guard let post = matchingPost, relevanceScore > 0.5 else {
            return nil // Нет подходящей статьи
        }
        
        // Telegraph URL генерируется при публикации, сохраняется в ZenPostModel
        // Для получения нужно взять из системы публикации или сформировать заново
        // Пока используем заголовок как slug
        let telegraphSlug = post.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-zа-яё0-9-]", with: "", options: .regularExpression)
            .prefix(50)
        
        // Формируем предполагаемый Telegraph URL
        let telegraphUrl = "https://telegra.ph/\(telegraphSlug)"
        
        return MatchingArticle(
            title: post.title,
            telegraphUrl: telegraphUrl,
            relevanceScore: relevanceScore
        )
    }
    
    /// Генерирует умный ответ с упоминанием нашей статьи
    private func generateSmartResponse(
        question: ZenQuestion,
        matchingArticle: MatchingArticle?
    ) async throws -> SmartResponse {
        
        let responsePrompt: String
        
        if let article = matchingArticle, let articleUrl = article.telegraphUrl {
            // Если есть подходящая статья - упоминаем её
            responsePrompt = """
            Ты — эксперт по путешествиям. Ответь на вопрос пользователя.
            
            ВОПРОС: "\(question.question)"
            
            У НАС ЕСТЬ СТАТЬЯ НА ЭТУ ТЕМУ: "\(article.title)"
            ССЫЛКА: \(articleUrl)
            
            ЗАДАЧА:
            1. Дай краткий полезный ответ (50-100 символов)
            2. ОБЯЗАТЕЛЬНО упомяни нашу статью: "Подробнее об этом я написал в статье: [ссылка]"
            3. Можешь мягко упомянуть @gdeVacationBot если вопрос про билеты
            
            ОБЩАЯ ДЛИНА: до 200 символов
            ТОН: дружелюбный, экспертный, полезный
            
            Ответь БЕЗ кавычек, сразу текстом для комментария.
            """
            
        } else {
            // Если нет подходящей статьи - общий ответ
            responsePrompt = """
            Ты — эксперт по путешествиям. Ответь на вопрос пользователя.
            
            ВОПРОС: "\(question.question)"
            
            ЗАДАЧА:
            1. Дай полезный ответ (до 150 символов)
            2. Упомяни @gdeVacationBot если вопрос про билеты/цены
            3. Будь конкретным (цены, сроки, факты)
            
            ТОН: дружелюбный, экспертный
            
            Ответь БЕЗ кавычек, сразу текстом для комментария.
            """
        }
        
        let answer = try await aiClient.generateText(
            systemPrompt: "Ты - эксперт по путешествиям, который помогает людям в комментариях.",
            userPrompt: responsePrompt
        )
        
        let relevanceScore = matchingArticle?.relevanceScore ?? 0.5
        
        return SmartResponse(
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            relevanceScore: relevanceScore
        )
    }
}

// MARK: - Модели

struct ZenQuestion {
    let postUrl: String
    let postTitle: String
    let question: String
    let category: String
}

struct MatchingArticle {
    let title: String
    let telegraphUrl: String?
    let relevanceScore: Double
}

struct SmartResponse {
    let answer: String
    let relevanceScore: Double
}

struct PromoSuggestion {
    let postUrl: String
    let postTitle: String
    let question: String
    let suggestedResponse: String
    let ourArticleUrl: String?
    let ourArticleTitle: String?
    let relevanceScore: Double
}
