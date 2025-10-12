import Foundation

/// Конфигурация для промо-активности
struct PromotionConfig {
    
    /// Ключевые слова для поиска постов
    static let searchKeywords = [
        "путешествия", "билеты", "туры", "отдых",
        "бюджетные направления", "виза", "отели",
        "куда поехать", "дешевые авиабилеты",
        "куда лететь", "поездка", "отпуск 2025"
    ]
    
    /// Часовые интервалы для активности (в московском времени)
    static let activeHours = [9, 12, 15, 18, 21]
    
    /// Максимальное количество комментариев в день
    static let maxCommentsPerDay = 20
    
    /// Максимальное количество ответов на один пост
    static let maxResponsesPerPost = 2
    
    /// Пауза между действиями (в секундах)
    static let actionDelay: TimeInterval = 30
    static let postDelay: TimeInterval = 60
    
    /// Шаблоны ответов для разных типов вопросов
    static let responseTemplates = [
        "билеты": [
            "Для поиска дешёвых билетов рекомендую @gdeVacationBot - он мониторит цены 24/7!",
            "Проверьте цены через @gdeVacationBot - там часто бывают скидки до 70%",
            "@gdeVacationBot поможет найти лучшие предложения на авиабилеты"
        ],
        "виза": [
            "С визой лучше не затягивать - документы лучше подавать за 2-3 месяца",
            "Проверьте актуальные требования на сайте посольства - правила часто меняются",
            "Для сложных виз рекомендую обратиться к визовому центру"
        ],
        "отели": [
            "Сравнивайте цены на Booking, Agoda и Ostrovok - разница может быть существенной",
            "Обратите внимание на отзывы и расположение - это важнее красивых фото",
            "Для экономии рассмотрите апартаменты вместо отелей"
        ],
        "общее": [
            "Отличный вопрос! У нас есть подробная статья на эту тему",
            "Спасибо за интерес к теме путешествий!",
            "Это популярное направление в этом сезоне"
        ]
    ]
    
    /// Критерии для выбора постов
    static let postCriteria = PostSelectionCriteria(
        minComments: 5,
        maxComments: 100,
        minLikes: 10,
        keywords: searchKeywords,
        excludeAuthors: ["gdeVacationBot"] // Исключаем свои посты
    )
    
    /// Настройки безопасности
    static let safetySettings = SafetySettings(
        maxActionsPerHour: 10,
        randomDelay: true,
        respectRateLimits: true,
        avoidSpamPatterns: true
    )
}

// MARK: - Вспомогательные структуры

struct PostSelectionCriteria {
    let minComments: Int
    let maxComments: Int
    let minLikes: Int
    let keywords: [String]
    let excludeAuthors: [String]
}

struct SafetySettings {
    let maxActionsPerHour: Int
    let randomDelay: Bool
    let respectRateLimits: Bool
    let avoidSpamPatterns: Bool
}

// MARK: - Статистика промо-активности

struct PromotionStats {
    let date: Date
    let postsAnalyzed: Int
    let commentsPosted: Int
    let questionsAnswered: Int
    let newSubscribers: Int
    let engagementRate: Double
    
    static func daily() -> PromotionStats {
        return PromotionStats(
            date: Date(),
            postsAnalyzed: 0,
            commentsPosted: 0,
            questionsAnswered: 0,
            newSubscribers: 0,
            engagementRate: 0.0
        )
    }
}
