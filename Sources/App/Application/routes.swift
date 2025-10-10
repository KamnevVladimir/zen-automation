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
    let openAIClient = OpenAIClient(
        client: app.client,
        apiKey: AppConfig.openAIKey
    )
    
    let validator = ContentValidator()
    let logger = Logger.zen()
    
    let contentGenerator = ContentGeneratorService(
        openAIClient: openAIClient,
        validator: validator,
        logger: logger
    )
    
    let notifier = TelegramNotifier(
        client: app.client,
        logger: logger
    )
    
    let publisher = ZenPublisher(
        logger: logger,
        notifier: notifier
    )
    
    let generationController = GenerationController(
        contentGenerator: contentGenerator,
        publisher: publisher
    )
    
    try generationController.boot(routes: app)
    
    app.logger.info("✅ Маршруты настроены")
}

