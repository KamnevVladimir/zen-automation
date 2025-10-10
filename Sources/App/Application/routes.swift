import Vapor

func routes(_ app: Application) throws {
    // Health check для Railway
    app.get("health") { req async -> HTTPStatus in
        return .ok
    }
    
    // API информация
    app.get { req async throws -> Response in
        let info = [
            "service": "zen-automation",
            "version": "1.0.0",
            "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        return try await info.encodeResponse(for: req)
    }
    
    // API маршруты
    let api = app.grouped("api", "v1")
    
    // Посты
    api.get("posts") { req async throws -> [ZenPostModel] in
        try await ZenPostModel.query(on: req.db)
            .sort(\.$publishedAt, .descending)
            .limit(20)
            .all()
    }
    
    // Метрики
    api.get("metrics") { req async throws -> Response in
        let totalPosts = try await ZenPostModel.query(on: req.db).count()
        let publishedPosts = try await ZenPostModel.query(on: req.db)
            .filter(\.$status == .published)
            .count()
        
        let metrics = [
            "total_posts": totalPosts,
            "published_posts": publishedPosts,
            "success_rate": totalPosts > 0 ? Double(publishedPosts) / Double(totalPosts) : 0.0
        ]
        
        return try await metrics.encodeResponse(for: req)
    }
    
    // RSS Feed
    api.get("rss") { req async throws -> Response in
        let posts = try await ZenPostModel.query(on: req.db)
            .filter(\.$status == .published)
            .sort(\.$publishedAt, .descending)
            .limit(50)
            .all()
        
        let rssPublisher = RSSPublisher()
        let rss = rssPublisher.generateRSSFeed(posts: posts)
        
        var response = Response()
        response.status = .ok
        response.headers.contentType = .init(type: "application", subType: "rss+xml")
        response.body = .init(string: rss)
        return response
    }
    
    // Регистрация контроллеров
    let validator = ContentValidator()
    let logger = Logger.zen()
    
    // Выбор AI провайдера
    let aiClient: AIClientProtocol
    switch AppConfig.aiProvider {
    case .openai:
        aiClient = OpenAIClient(
            client: app.client,
            apiKey: AppConfig.openAIKey
        )
        logger.info("🤖 Используется OpenAI GPT-4")
    case .anthropic:
        aiClient = AnthropicClient(
            client: app.client,
            apiKey: AppConfig.anthropicKey,
            model: AppConfig.anthropicModel
        )
        logger.info("🤖 Используется Anthropic Claude")
    case .yandexgpt:
        // TODO: Добавить YandexGPT клиент
        aiClient = AnthropicClient(
            client: app.client,
            apiKey: AppConfig.anthropicKey,
            model: AppConfig.anthropicModel
        )
        logger.warning("⚠️ YandexGPT пока не реализован, используется Claude")
    }
    
    let contentGenerator = ContentGeneratorService(
        aiClient: aiClient,
        validator: validator,
        logger: logger
    )
    
    let notifier = TelegramNotifier(
        client: app.client,
        logger: logger
    )
    
    // Выбор метода публикации
    let publisher: ZenPublisherProtocol
    switch AppConfig.publishMethod {
    case .telegram:
        publisher = TelegramChannelPublisher(
            client: app.client,
            logger: logger
        )
        logger.info("📱 Публикация через Telegram Channel")
    case .rss:
        publisher = ZenPublisher(
            logger: logger,
            notifier: notifier
        )
        logger.info("📰 Публикация через RSS")
    case .direct:
        publisher = ZenPublisher(
            logger: logger,
            notifier: notifier
        )
        logger.info("✉️ Прямая публикация (уведомления в Telegram)")
    }
    
    let generationController = GenerationController(
        contentGenerator: contentGenerator,
        publisher: publisher
    )
    
    try generationController.boot(routes: app)
    
    app.logger.info("✅ Маршруты настроены")
}

