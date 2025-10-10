import Vapor
import Fluent
import FluentPostgresDriver
import Queues

public func configure(_ app: Application) throws {
    // Конфигурация сервера
    app.http.server.configuration.hostname = Environment.get("HOSTNAME") ?? "0.0.0.0"
    app.http.server.configuration.port = Int(Environment.get("PORT") ?? "8080") ?? 8080
    
    // Конфигурация базы данных
    if let databaseURL = Environment.get("DATABASE_URL") {
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
    } else {
        app.logger.warning("DATABASE_URL не задан, используется локальная БД")
        app.databases.use(.postgres(
            hostname: Environment.get("DB_HOST") ?? "localhost",
            port: Environment.get("DB_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DB_USER") ?? "postgres",
            password: Environment.get("DB_PASS") ?? "postgres",
            database: Environment.get("DB_NAME") ?? "zenautomation"
        ), as: .psql)
    }
    
    // Миграции
    app.migrations.add(CreateZenPosts())
    app.migrations.add(CreateZenImages())
    app.migrations.add(CreateZenMetrics())
    app.migrations.add(CreatePostTemplates())
    app.migrations.add(CreateTrendingDestinations())
    app.migrations.add(CreateGenerationLogs())
    
    // Запуск миграций автоматически
    try app.autoMigrate().wait()
    
    // Маршруты
    try routes(app)
    
    app.logger.info("✅ Zen Automation сконфигурирован")
}

