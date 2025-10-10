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
            .filter(\.$status, .equal, PostStatus.published)
            .count()
        
        struct MetricsResponse: Content {
            let total_posts: Int
            let published_posts: Int
            let success_rate: Double
        }
        
        let metrics = MetricsResponse(
            total_posts: totalPosts,
            published_posts: publishedPosts,
            success_rate: totalPosts > 0 ? Double(publishedPosts) / Double(totalPosts) : 0.0
        )
        
        return try await metrics.encodeResponse(for: req)
    }
    
    // RSS Feed для T-Journal
    api.get("rss") { req async throws -> Response in
        let posts = try await ZenPostModel.query(on: req.db)
            .filter(\.$status, .equal, PostStatus.published)
            .sort(\.$publishedAt, .descending)
            .limit(20)
            .all()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let rssItems = posts.map { post in
            let pubDate = dateFormatter.string(from: post.publishedAt ?? post.createdAt ?? Date())
            return """
            <item>
                <title><![CDATA[\(post.title)]]></title>
                <description><![CDATA[\(post.content.prefix(500))...]]></description>
                <link>https://t.me/gdeTravel</link>
                <pubDate>\(pubDate)</pubDate>
                <guid>\(post.id?.uuidString ?? UUID().uuidString)</guid>
            </item>
            """
        }.joined(separator: "\n")
        
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>🛫 Дешевые путешествия</title>
                <description>Актуальные советы по дешевым путешествиям и авиабилетам</description>
                <link>https://t.me/gdeTravel</link>
                <language>ru</language>
                \(rssItems)
            </channel>
        </rss>
        """
        
        var response = Response()
        response.status = .ok
        response.headers.contentType = .init(type: "application", subType: "rss+xml; charset=utf-8")
        response.body = .init(string: rss)
        return response
    }
    
    // Кросс-постинг: Telegram Channel → Дзен + T-Journal
    
    // Регистрация контроллеров
    let validator = ContentValidator()
    let logger = Logger.zen()
    
    // AI клиент (только Anthropic Claude)
    let aiClient = AnthropicClient(client: app.client)
    logger.info("🤖 Используется Anthropic Claude (\(AppConfig.anthropicModel))")
    
    let contentGenerator = ContentGeneratorService(
        aiClient: aiClient,
        validator: validator,
        logger: logger
    )
    
    let notifier = TelegramNotifier(
        client: app.client,
        logger: logger
    )
    
    // Publisher (только Telegram Channel)
    let publisher = TelegramChannelPublisher(
        client: app.client,
        logger: logger
    )
    logger.info("📱 Публикация через Telegram Channel (\(AppConfig.telegramChannelId))")
    
    let generationController = GenerationController(
        contentGenerator: contentGenerator,
        publisher: publisher as ZenPublisherProtocol
    )
    
    let telegramBotController = TelegramBotController(
        contentGenerator: contentGenerator,
        publisher: publisher as ZenPublisherProtocol
    )
    
    // Запуск Long Polling для Telegram бота
    let pollingService = TelegramPollingService(
        app: app,
        controller: telegramBotController
    )
    
    // Запускаем polling после старта приложения
    app.lifecycle.use(
        TelegramPollingLifecycleHandler(pollingService: pollingService)
    )
    
    try generationController.boot(routes: app)
    
    app.logger.info("✅ Маршруты настроены")
    app.logger.info("🤖 Telegram Bot готов к приему команд от пользователя \(AppConfig.adminUserId)")
}

