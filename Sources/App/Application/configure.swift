import Vapor
import Fluent
import FluentPostgresDriver
import PostgresKit
import Queues
import NIOSSL
import Foundation

public func configure(_ app: Application) throws {
    // Конфигурация сервера
    app.http.server.configuration.hostname = Environment.get("HOSTNAME") ?? "0.0.0.0"
    // Безопасный парсинг PORT переменной
    let portString = Environment.get("PORT") ?? "8080"
    let port = Int(portString) ?? 8080
    app.http.server.configuration.port = port
    app.logger.info("🌐 Сервер запущен на порту: \(port)")
    
    // Конфигурация базы данных
    if let databaseURL = Environment.get("DATABASE_URL") {
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateVerification = .none // Отключить проверку сертификатов для Railway
        
        // Создаем конфигурацию PostgreSQL с SSL
        var config = try PostgresConfiguration(url: databaseURL)!
        config.tlsConfiguration = tlsConfig
        
        app.databases.use(
            DatabaseConfigurationFactory.postgres(configuration: config),
            as: .psql
        )
    } else {
        app.logger.warning("DATABASE_URL не задан, используется локальная БД")
        app.databases.use(
            DatabaseConfigurationFactory.postgres(configuration: .init(
                hostname: Environment.get("DB_HOST") ?? "localhost",
                port: Int(Environment.get("DB_PORT") ?? "5432") ?? 5432,
                username: Environment.get("DB_USER") ?? "postgres",
                password: Environment.get("DB_PASS") ?? "postgres",
                database: Environment.get("DB_NAME") ?? "zenautomation"
            )),
            as: .psql
        )
    }
    
    // Миграции
    app.migrations.add(CreateZenPosts())
    app.migrations.add(CreateZenImages())
    app.migrations.add(CreateZenMetrics())
    app.migrations.add(CreatePostTemplates())
    app.migrations.add(CreateTrendingDestinations())
    app.migrations.add(CreateGenerationLogs())
    app.migrations.add(AddShortAndFullPost())
    app.migrations.add(AddZenAndTelegraphUrls())
    
    // Запуск миграций автоматически
    try app.autoMigrate().wait()
    
    // Маршруты
    try routes(app)
    
    // Запускаем встроенный планировщик для автопостов
    let scheduler = SimpleScheduler(app: app)
    scheduler.startPostSchedule()
    
    // Сохраняем ссылку на планировщик чтобы не удалился
    app.storage[SimpleSchedulerKey.self] = scheduler
    
    app.logger.info("✅ Zen Automation сконфигурирован")
    app.logger.info("📅 Автопосты: 2 раза в день")
    app.logger.info("   🌅 08:00 MSK - утренний пост (лайфхаки)")
    app.logger.info("   🌆 20:00 MSK - вечерний пост (бюджетные направления)")
    app.logger.info("ℹ️ Эндпоинты: POST /api/v1/generate - ручная генерация поста")
}

// MARK: - Storage Key для планировщика

struct SimpleSchedulerKey: StorageKey {
    typealias Value = SimpleScheduler
}

