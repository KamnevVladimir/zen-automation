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
        
        // 2. Используем Claude для поиска РЕАЛЬНЫХ популярных постов в Яндекс Дзене
        logger.info("🌐 Claude ищет реальные посты в Яндекс Дзене...")
        
        let searchPrompt = """
        Найди 3 РЕАЛЬНЫХ популярных поста в Яндекс Дзене про путешествия, где люди активно задают вопросы в комментариях.
        
        КРИТЕРИИ ПОИСКА:
        - Посты должны быть про: билеты, визы, бюджет путешествий, отдых за границей
        - Посты должны быть популярными (много просмотров и комментариев)
        - Опубликованы в последние 2-3 месяца (актуальные)
        - На русском языке
        
        Используй поиск в Яндекс Дзене по запросам:
        - "где купить дешёвые билеты 2025"
        - "сколько денег нужно на отдых таиланд"
        - "виза россиянам куда не нужна"
        
        ВЕРНИ JSON (строго в таком формате):
        [
          {
            "url": "полная ссылка на пост в dzen.ru",
            "title": "название поста",
            "typical_question": "типичный вопрос из комментариев",
            "category": "билеты/виза/бюджет"
          }
        ]
        
        ВАЖНО: Ссылки должны быть РЕАЛЬНЫМИ и работающими!
        """
        
        let searchResult = try await aiClient.generateText(
            systemPrompt: "Ты - поисковый ассистент который ищет реальные посты в Яндекс Дзене. Отвечай только в JSON формате.",
            userPrompt: searchPrompt
        )
        
        // Парсим результат поиска
        guard let jsonData = searchResult.data(using: .utf8),
              let postsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            logger.warning("⚠️ Claude не смог найти посты, использую запасные варианты")
            // Запасные реальные категории Дзена
            return try await useFallbackPosts(ourPosts: ourPosts)
        }
        
        // Конвертируем в ZenQuestion
        let exampleQuestions = postsArray.compactMap { post -> ZenQuestion? in
            guard let url = post["url"] as? String,
                  let title = post["title"] as? String,
                  let question = post["typical_question"] as? String,
                  let category = post["category"] as? String else {
                return nil
            }
            
            return ZenQuestion(
                postUrl: url,
                postTitle: title,
                question: question,
                category: category
            )
        }
        
        logger.info("✅ Claude нашёл \(exampleQuestions.count) реальных постов")
        
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
                ourArticleUrl: matchingArticle?.zenArticleUrl,
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
        
        // Используем URL из Яндекс Дзена если есть, иначе Telegraph
        let articleUrl = post.zenArticleUrl ?? post.telegraphUrl ?? "https://dzen.ru/gototravel"
        
        return MatchingArticle(
            title: post.title,
            zenArticleUrl: articleUrl,
            relevanceScore: relevanceScore
        )
    }
    
    /// Генерирует умный ответ с упоминанием нашей статьи
    private func generateSmartResponse(
        question: ZenQuestion,
        matchingArticle: MatchingArticle?
    ) async throws -> SmartResponse {
        
        let responsePrompt: String
        
        if let article = matchingArticle, let articleUrl = article.zenArticleUrl {
            // Если есть подходящая статья - упоминаем наш Яндекс Дзен
            responsePrompt = """
            Ты — эксперт по путешествиям. Ответь на вопрос в Яндекс Дзене.
            
            ВОПРОС: "\(question.question)"
            
            У НАС ЕСТЬ СТАТЬЯ В ДЗЕНЕ: "\(article.title)"
            ССЫЛКА НА НАШ ДЗЕН: \(articleUrl)
            
            ФОРМАТ ОТВЕТА (СТРОГО):
            [Краткий совет/ответ 1-2 предложения]. На твой вопрос есть ответ в статье, которую я недавно читал на нашем канале в Дзене. Ссылка: \(articleUrl). Может тебе будет полезно!
            
            ПРАВИЛА:
            - Первое предложение = конкретный совет (сервисы, цены, факты)
            - Второе предложение = ОБЯЗАТЕЛЬНО фраза "На твой вопрос есть ответ в статье..."
            - Третье = ссылка на НАШ ДЗЕН
            - НЕ упоминать @gdeVacationBot
            - Общая длина: 150-250 символов
            - Тон: дружелюбный, как советует опытный путешественник
            
            ПРИМЕР:
            "Я использую Aviasales и Skyscanner для сравнения цен. На твой вопрос есть ответ в статье, которую я недавно читал на нашем канале в Дзене. Ссылка: https://dzen.ru/gototravel. Может тебе будет полезно!"
            
            Ответь БЕЗ кавычек, сразу текстом для комментария.
            """
            
        } else {
            // Если нет подходящей статьи - общий ответ с упоминанием нашего канала
            responsePrompt = """
            Ты — эксперт по путешествиям. Ответь на вопрос в Яндекс Дзене.
            
            ВОПРОС: "\(question.question)"
            
            ФОРМАТ ОТВЕТА:
            [Конкретный совет 1-2 предложения]. Больше полезных советов про путешествия публикую на канале: https://dzen.ru/gototravel
            
            ПРАВИЛА:
            - Дай конкретный совет с примерами, цифрами, фактами
            - Упомяни НАШ КАНАЛ В ДЗЕНЕ: https://dzen.ru/gototravel
            - НЕ упоминать @gdeVacationBot
            - Длина: 100-200 символов
            - Тон: дружелюбный, экспертный
            
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
    
    /// Запасные варианты если Claude не смог найти посты
    private func useFallbackPosts(ourPosts: [ZenPostModel]) async throws -> [PromoSuggestion] {
        logger.info("📋 Использую запасные популярные категории Дзена")
        
        // Популярные разделы Дзена где можно комментировать
        let fallbackQuestions = [
            ZenQuestion(
                postUrl: "https://dzen.ru/travel",
                postTitle: "Раздел 'Путешествия' в Яндекс Дзен",
                question: "Где искать дешёвые билеты на самолёт?",
                category: "билеты"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/news/rubric/tourism",
                postTitle: "Новости туризма",
                question: "Сколько денег брать с собой в отпуск?",
                category: "бюджет"
            ),
            ZenQuestion(
                postUrl: "https://dzen.ru/id/tourism-tips",
                postTitle: "Советы путешественникам",
                question: "Куда можно поехать без визы из России?",
                category: "виза"
            )
        ]
        
        var suggestions: [PromoSuggestion] = []
        
        for question in fallbackQuestions {
            let matchingArticle = try await findBestMatchingArticle(
                question: question,
                ourPosts: ourPosts
            )
            
            let response = try await generateSmartResponse(
                question: question,
                matchingArticle: matchingArticle
            )
            
            suggestions.append(
                PromoSuggestion(
                    postUrl: question.postUrl,
                    postTitle: question.postTitle,
                    question: question.question,
                    suggestedResponse: response.answer,
                    ourArticleUrl: matchingArticle?.zenArticleUrl,
                    ourArticleTitle: matchingArticle?.title,
                    relevanceScore: response.relevanceScore
                )
            )
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        }
        
        return suggestions
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
    let zenArticleUrl: String?
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
