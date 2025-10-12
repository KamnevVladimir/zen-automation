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
    
    // Запуск миграций автоматически
    try app.autoMigrate().wait()
    
    // Миграции для очередей
    try app.queues.setup(app)
    
    // Конфигурация очередей и планировщика
    try configureQueues(app)
    
    // Маршруты
    try routes(app)
    
    app.logger.info("✅ Zen Automation сконфигурирован")
}

/// Конфигурация очередей и планировщика задач
private func configureQueues(_ app: Application) throws {
    // Настройка очередей с базой данных
    app.queues.use(.database(app.db))
    
    // Регистрация джобов
    app.queues.add(DailyPostJob(
        contentGenerator: ContentGeneratorService(),
        publisher: ZenPublisher(),
        notifier: TelegramNotifier(app: app)
    ))
    
    // Запуск планировщика
    try app.queues.startInProcessScheduler()
    
    // Настройка расписания
    try setupDailySchedule(app)
    
    app.logger.info("📅 Планировщик задач настроен")
}

/// Настройка ежедневного расписания постов
private func setupDailySchedule(_ app: Application) throws {
    let schedules = ScheduleConfig.defaultSchedules
    
    for schedule in schedules {
        // Создаём cron выражение для ежедневного выполнения
        let cronExpression = "\(schedule.minute) \(schedule.hour) * * *"
        
        app.queues.schedule(DailyPostJob.self)
            .using(Calendar(identifier: .gregorian))
            .cron(cronExpression)
            .on(.default)
        
        app.logger.info("📝 Настроено расписание: \(schedule.timeString) - \(schedule.templateType.rawValue)")
    }
}

