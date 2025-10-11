# 🎯 Автоматический бот для ответов на вопросы в Telegram каналах

## 📋 Содержание

1. [Архитектура системы](#архитектура-системы)
2. [Технический стек](#технический-стек)
3. [Структура проекта](#структура-проекта)
4. [Пошаговая реализация](#пошаговая-реализация)
5. [Безопасность и анти-бан меры](#безопасность-и-анти-бан-меры)
6. [Деплой и мониторинг](#деплой-и-мониторинг)

---

## 🏗 Архитектура системы

```
┌─────────────────────────────────────────────────────────┐
│                    AUTO COMMENT BOT                      │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           v               v               v
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Channel  │    │ Comment  │    │  Reply   │
    │ Monitor  │    │ Analyzer │    │  Poster  │
    └──────────┘    └──────────┘    └──────────┘
           │               │               │
           v               v               v
    ┌──────────────────────────────────────────┐
    │         PostgreSQL Database              │
    │  - channels                              │
    │  - posts                                 │
    │  - comments                              │
    │  - replies (для анти-спама)             │
    └──────────────────────────────────────────┘
                           │
                           v
                   ┌──────────────┐
                   │  Claude AI   │
                   │  (для        │
                   │  генерации   │
                   │  ответов)    │
                   └──────────────┘
```

---

## 🛠 Технический стек

### Backend
- **Swift 5.9** + **Vapor 4**
- **PostgreSQL** для хранения данных
- **Telegram Bot API** для взаимодействия
- **Claude AI API** для генерации ответов

### Дополнительно
- **Docker** для контейнеризации
- **Railway/Fly.io** для хостинга
- **Redis** (опционально) для кэширования

---

## 📁 Структура проекта

```
telegram-comment-bot/
├── Package.swift
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── README.md
│
├── Sources/
│   └── App/
│       ├── Application/
│       │   ├── main.swift
│       │   ├── configure.swift
│       │   └── routes.swift
│       │
│       ├── Core/
│       │   ├── Models/
│       │   │   ├── Channel.swift
│       │   │   ├── Post.swift
│       │   │   ├── Comment.swift
│       │   │   └── Reply.swift
│       │   │
│       │   ├── Database/
│       │   │   ├── Migrations/
│       │   │   │   ├── CreateChannels.swift
│       │   │   │   ├── CreatePosts.swift
│       │   │   │   ├── CreateComments.swift
│       │   │   │   └── CreateReplies.swift
│       │   │   └── DatabaseConfig.swift
│       │   │
│       │   └── Services/
│       │       ├── TelegramClient.swift
│       │       ├── ClaudeClient.swift
│       │       └── Logger.swift
│       │
│       ├── Features/
│       │   ├── ChannelMonitor/
│       │   │   ├── ChannelDiscoveryService.swift
│       │   │   ├── ChannelMonitorService.swift
│       │   │   └── PostParserService.swift
│       │   │
│       │   ├── CommentAnalyzer/
│       │   │   ├── CommentParserService.swift
│       │   │   ├── QuestionDetectorService.swift
│       │   │   ├── KeywordMatcher.swift
│       │   │   └── SentimentAnalyzer.swift
│       │   │
│       │   ├── ReplyGenerator/
│       │   │   ├── AIReplyService.swift
│       │   │   ├── TemplateEngine.swift
│       │   │   └── ContextBuilder.swift
│       │   │
│       │   └── ReplyPoster/
│       │       ├── CommentPosterService.swift
│       │       ├── AntiSpamService.swift
│       │       └── RateLimiter.swift
│       │
│       └── Jobs/
│           ├── ChannelScanJob.swift
│           ├── CommentAnalysisJob.swift
│           └── ReplyPostingJob.swift
│
└── Tests/
    └── AppTests/
        ├── ChannelMonitorTests.swift
        ├── CommentAnalyzerTests.swift
        └── ReplyGeneratorTests.swift
```

---

## 🚀 Пошаговая реализация

### Шаг 1: Инициализация проекта

```bash
# Создаём новый проект
mkdir telegram-comment-bot
cd telegram-comment-bot

# Инициализируем Swift Package
swift package init --type executable

# Создаём структуру директорий
mkdir -p Sources/App/{Application,Core/{Models,Database/Migrations,Services},Features/{ChannelMonitor,CommentAnalyzer,ReplyGenerator,ReplyPoster},Jobs}
```

### Шаг 2: Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "telegram-comment-bot",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor Framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        
        // Fluent + PostgreSQL
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        
        // Queues для фоновых задач
        .package(url: "https://github.com/vapor/queues.git", from: "1.13.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Queues", package: "queues"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        )
    ]
)
```

### Шаг 3: Модели данных

#### Channel.swift
```swift
import Fluent
import Vapor

final class Channel: Model, Content {
    static let schema = "channels"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "username")
    var username: String // @aviasales
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "category")
    var category: String // travel, finance, tech
    
    @Field(key: "subscribers_count")
    var subscribersCount: Int
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Field(key: "last_scanned_at")
    var lastScannedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Children(for: \.$channel)
    var posts: [Post]
    
    init() {}
    
    init(
        id: UUID? = nil,
        username: String,
        title: String,
        category: String,
        subscribersCount: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.username = username
        self.title = title
        self.category = category
        self.subscribersCount = subscribersCount
        self.isActive = isActive
    }
}
```

#### Post.swift
```swift
import Fluent
import Vapor

final class Post: Model, Content {
    static let schema = "posts"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "channel_id")
    var channel: Channel
    
    @Field(key: "telegram_message_id")
    var telegramMessageId: Int
    
    @Field(key: "text")
    var text: String
    
    @Field(key: "views_count")
    var viewsCount: Int?
    
    @Field(key: "comments_count")
    var commentsCount: Int?
    
    @Field(key: "posted_at")
    var postedAt: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Children(for: \.$post)
    var comments: [Comment]
    
    init() {}
}
```

#### Comment.swift
```swift
import Fluent
import Vapor

final class Comment: Model, Content {
    static let schema = "comments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: Post
    
    @Field(key: "telegram_comment_id")
    var telegramCommentId: Int
    
    @Field(key: "author_username")
    var authorUsername: String?
    
    @Field(key: "author_first_name")
    var authorFirstName: String
    
    @Field(key: "text")
    var text: String
    
    @Field(key: "is_question")
    var isQuestion: Bool
    
    @Field(key: "keywords_matched")
    var keywordsMatched: [String]
    
    @Field(key: "sentiment_score")
    var sentimentScore: Double? // -1.0 to 1.0
    
    @Field(key: "replied")
    var replied: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @OptionalChild(for: \.$comment)
    var reply: Reply?
    
    init() {}
}
```

#### Reply.swift
```swift
import Fluent
import Vapor

final class Reply: Model, Content {
    static let schema = "replies"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "comment_id")
    var comment: Comment
    
    @Field(key: "generated_text")
    var generatedText: String
    
    @Field(key: "posted")
    var posted: Bool
    
    @Field(key: "telegram_reply_id")
    var telegramReplyId: Int?
    
    @Field(key: "posted_at")
    var postedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
}
```

### Шаг 4: Миграции

#### CreateChannels.swift
```swift
import Fluent

struct CreateChannels: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("channels")
            .id()
            .field("username", .string, .required)
            .field("title", .string, .required)
            .field("category", .string, .required)
            .field("subscribers_count", .int, .required)
            .field("is_active", .bool, .required)
            .field("last_scanned_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "username")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("channels").delete()
    }
}
```

### Шаг 5: Telegram Client

#### TelegramClient.swift
```swift
import Vapor

struct TelegramMessage: Codable {
    let messageId: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?
    let date: Int
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from, chat, text, date
    }
}

struct TelegramUser: Codable {
    let id: Int
    let firstName: String
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case username
    }
}

struct TelegramChat: Codable {
    let id: Int
    let type: String
    let title: String?
    let username: String?
}

final class TelegramClient {
    private let client: Client
    private let botToken: String
    private let logger: Logger
    private let baseURL = "https://api.telegram.org"
    
    init(client: Client, botToken: String, logger: Logger) {
        self.client = client
        self.botToken = botToken
        self.logger = logger
    }
    
    // Получить информацию о канале
    func getChat(username: String) async throws -> TelegramChat {
        let url = URI(string: "\(baseURL)/bot\(botToken)/getChat")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = ["chat_id": "@\(username)"]
        request.body = .init(data: try JSONSerialization.data(withJSONObject: body))
        
        let response = try await client.send(request)
        
        struct Response: Codable {
            let ok: Bool
            let result: TelegramChat
        }
        
        let apiResponse = try response.content.decode(Response.self)
        return apiResponse.result
    }
    
    // Получить последние сообщения из канала (через поиск)
    func getChannelPosts(username: String, limit: Int = 20) async throws -> [TelegramMessage] {
        // Telegram Bot API не позволяет напрямую читать сообщения из публичных каналов
        // Нужно использовать Telegram Client API (MTProto) или сделать бота администратором
        
        // Для простоты используем метод через getUpdates если бот администратор
        let url = URI(string: "\(baseURL)/bot\(botToken)/getUpdates")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "limit": limit,
            "allowed_updates": ["channel_post", "message"]
        ]
        request.body = .init(data: try JSONSerialization.data(withJSONObject: body))
        
        let response = try await client.send(request)
        
        struct Update: Codable {
            let updateId: Int
            let channelPost: TelegramMessage?
            let message: TelegramMessage?
            
            enum CodingKeys: String, CodingKey {
                case updateId = "update_id"
                case channelPost = "channel_post"
                case message
            }
        }
        
        struct Response: Codable {
            let ok: Bool
            let result: [Update]
        }
        
        let apiResponse = try response.content.decode(Response.self)
        return apiResponse.result.compactMap { $0.channelPost ?? $0.message }
    }
    
    // Отправить комментарий (ответ на сообщение)
    func sendComment(
        chatId: String,
        replyToMessageId: Int,
        text: String
    ) async throws -> TelegramMessage {
        let url = URI(string: "\(baseURL)/bot\(botToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "reply_to_message_id": replyToMessageId,
            "parse_mode": "HTML"
        ]
        request.body = .init(data: try JSONSerialization.data(withJSONObject: body))
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            logger.error("❌ Telegram sendMessage error: \(response.status)")
            throw Abort(.internalServerError)
        }
        
        struct Response: Codable {
            let ok: Bool
            let result: TelegramMessage
        }
        
        let apiResponse = try response.content.decode(Response.self)
        logger.info("✅ Comment posted: \(text.prefix(50))...")
        
        return apiResponse.result
    }
}
```

### Шаг 6: Question Detector Service

#### QuestionDetectorService.swift
```swift
import Vapor

struct QuestionPattern {
    let keywords: [String]
    let category: String
    let weight: Double
}

final class QuestionDetectorService {
    private let logger: Logger
    
    // Паттерны для определения вопросов о путешествиях
    private let travelPatterns: [QuestionPattern] = [
        // Поиск билетов
        QuestionPattern(
            keywords: ["где найти", "где купить", "где искать", "как найти", "где дешевле"],
            category: "ticket_search",
            weight: 1.0
        ),
        QuestionPattern(
            keywords: ["билет", "авиабилет", "перелёт", "рейс"],
            category: "tickets",
            weight: 0.8
        ),
        
        // Цены и скидки
        QuestionPattern(
            keywords: ["сколько стоит", "какая цена", "подешевеет", "скидки", "акции"],
            category: "pricing",
            weight: 0.9
        ),
        
        // Направления
        QuestionPattern(
            keywords: ["куда", "в какую страну", "какое направление", "что посоветуете"],
            category: "destinations",
            weight: 0.7
        ),
        
        // Сервисы и приложения
        QuestionPattern(
            keywords: ["какой сервис", "какое приложение", "какой сайт", "где лучше"],
            category: "services",
            weight: 1.0
        ),
        
        // Советы
        QuestionPattern(
            keywords: ["посоветуйте", "подскажите", "помогите", "кто знает", "может кто"],
            category: "advice",
            weight: 0.9
        ),
        
        // Экономия
        QuestionPattern(
            keywords: ["экономить", "сэкономить", "дешевле", "выгодно", "бюджетно"],
            category: "savings",
            weight: 0.8
        )
    ]
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    // Определить, является ли комментарий вопросом
    func isQuestion(_ text: String) -> Bool {
        let normalized = text.lowercased()
        
        // Проверка на вопросительные знаки
        if normalized.contains("?") {
            return true
        }
        
        // Проверка на вопросительные слова в начале
        let questionWords = ["где", "как", "когда", "почему", "зачем", "какой", "кто", "что", "сколько"]
        for word in questionWords {
            if normalized.hasPrefix(word + " ") {
                return true
            }
        }
        
        return false
    }
    
    // Найти совпадающие ключевые слова
    func matchKeywords(_ text: String) -> [String] {
        let normalized = text.lowercased()
        var matched: [String] = []
        
        for pattern in travelPatterns {
            for keyword in pattern.keywords {
                if normalized.contains(keyword) {
                    matched.append(keyword)
                }
            }
        }
        
        return Array(Set(matched)) // уникальные
    }
    
    // Определить релевантность комментария (0.0 - 1.0)
    func calculateRelevance(_ text: String) -> Double {
        let normalized = text.lowercased()
        var score = 0.0
        
        // Базовая проверка на вопрос
        if isQuestion(normalized) {
            score += 0.3
        }
        
        // Проверка паттернов
        for pattern in travelPatterns {
            for keyword in pattern.keywords {
                if normalized.contains(keyword) {
                    score += pattern.weight * 0.1
                }
            }
        }
        
        // Бонус за длину (развёрнутые вопросы лучше)
        let wordCount = normalized.split(separator: " ").count
        if wordCount > 5 && wordCount < 50 {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
    
    // Определить категорию вопроса
    func detectCategory(_ text: String) -> String? {
        let normalized = text.lowercased()
        var bestMatch: (category: String, score: Double) = ("unknown", 0.0)
        
        for pattern in travelPatterns {
            var score = 0.0
            for keyword in pattern.keywords {
                if normalized.contains(keyword) {
                    score += pattern.weight
                }
            }
            
            if score > bestMatch.score {
                bestMatch = (pattern.category, score)
            }
        }
        
        return bestMatch.score > 0 ? bestMatch.category : nil
    }
}
```

### Шаг 7: AI Reply Service

#### AIReplyService.swift
```swift
import Vapor

final class AIReplyService {
    private let client: Client
    private let apiKey: String
    private let logger: Logger
    private let botUsername: String
    
    init(
        client: Client,
        apiKey: String,
        botUsername: String,
        logger: Logger
    ) {
        self.client = client
        self.apiKey = apiKey
        self.botUsername = botUsername
        self.logger = logger
    }
    
    // Генерация ответа через Claude AI
    func generateReply(
        question: String,
        context: QuestionContext
    ) async throws -> String {
        let prompt = buildPrompt(question: question, context: context)
        
        let url = URI(string: "https://api.anthropic.com/v1/messages")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 300,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.body = .init(data: try JSONSerialization.data(withJSONObject: body))
        
        let response = try await client.send(request)
        
        struct ClaudeResponse: Codable {
            struct Content: Codable {
                let text: String
            }
            let content: [Content]
        }
        
        let aiResponse = try response.content.decode(ClaudeResponse.self)
        let generatedText = aiResponse.content.first?.text ?? ""
        
        // Добавляем упоминание бота в конце
        return "\(generatedText)\n\n💡 Попробуйте @\(botUsername) — поможет найти лучшие цены"
    }
    
    // Построение промпта для AI
    private func buildPrompt(question: String, context: QuestionContext) -> String {
        """
        Ты — полезный помощник в комментариях Telegram канала о путешествиях.
        
        **Вопрос пользователя:**
        "\(question)"
        
        **Контекст:**
        - Категория: \(context.category ?? "общий вопрос")
        - Канал: \(context.channelName)
        - Тема поста: \(context.postTopic ?? "путешествия")
        
        **Задача:**
        Напиши короткий (2-3 предложения), полезный ответ на вопрос.
        
        **Правила:**
        1. Будь дружелюбным и экспертным
        2. Давай конкретный совет, не воду
        3. НЕ упоминай бота напрямую (это добавится автоматически)
        4. Используй эмодзи умеренно (1-2 шт)
        5. Пиши по-русски
        
        **Примеры хороших ответов:**
        
        Вопрос: "Где найти дешевые билеты в Турцию?"
        Ответ: "Советую мониторить сразу несколько агрегаторов: Aviasales, Skyscanner, Яндекс Путешествия. Лучшие цены обычно в среду-четверг. Ещё можно смотреть на ошибочные тарифы — иногда находятся билеты на 50% дешевле."
        
        Вопрос: "Сколько стоит слетать в Грузию?"
        Ответ: "Реально уложиться в 15-20 тысяч на неделю: билеты 6-8к, жильё 300-500₽/день, еда 500₽/день. В межсезон ещё дешевле. Грузия — один из самых бюджетных вариантов для россиян 😊"
        
        Теперь ответь на вопрос выше:
        """
    }
}

struct QuestionContext {
    let category: String?
    let channelName: String
    let postTopic: String?
    let keywordsMatched: [String]
}
```

### Шаг 8: Comment Poster Service (с анти-спамом)

#### CommentPosterService.swift
```swift
import Vapor
import Fluent

final class CommentPosterService {
    private let telegramClient: TelegramClient
    private let antiSpam: AntiSpamService
    private let db: Database
    private let logger: Logger
    
    init(
        telegramClient: TelegramClient,
        antiSpam: AntiSpamService,
        db: Database,
        logger: Logger
    ) {
        self.telegramClient = telegramClient
        self.antiSpam = antiSpam
        self.db = db
        self.logger = logger
    }
    
    // Опубликовать ответ
    func postReply(
        to comment: Comment,
        withText replyText: String
    ) async throws {
        // 1. Проверка анти-спама
        guard try await antiSpam.canPost(to: comment) else {
            logger.warning("⚠️ Anti-spam: cannot post reply to comment \(comment.id?.uuidString ?? "unknown")")
            return
        }
        
        // 2. Получаем информацию о посте и канале
        let post = try await comment.$post.get(on: db)
        let channel = try await post.$channel.get(on: db)
        
        // 3. Случайная задержка (выглядит естественнее)
        let delay = TimeInterval.random(in: 30...120) // 30-120 секунд
        logger.info("⏳ Waiting \(Int(delay))s before posting reply...")
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // 4. Отправка комментария
        do {
            let sentMessage = try await telegramClient.sendComment(
                chatId: channel.username,
                replyToMessageId: comment.telegramCommentId,
                text: replyText
            )
            
            // 5. Сохраняем информацию об ответе
            let reply = Reply()
            reply.$comment.id = try comment.requireID()
            reply.generatedText = replyText
            reply.posted = true
            reply.telegramReplyId = sentMessage.messageId
            reply.postedAt = Date()
            
            try await reply.save(on: db)
            
            // 6. Обновляем флаг в комментарии
            comment.replied = true
            try await comment.save(on: db)
            
            // 7. Регистрируем в анти-спаме
            try await antiSpam.recordPost(to: comment)
            
            logger.info("✅ Reply posted successfully to comment \(comment.id?.uuidString ?? "unknown")")
            
        } catch {
            logger.error("❌ Failed to post reply: \(error)")
            throw error
        }
    }
}
```

#### AntiSpamService.swift
```swift
import Vapor
import Fluent

final class AntiSpamService {
    private let db: Database
    private let logger: Logger
    
    // Лимиты для анти-спама
    private let maxRepliesPerHour = 5
    private let maxRepliesPerChannel = 10
    private let minTimeBetweenReplies: TimeInterval = 300 // 5 минут
    private let maxRepliesPerDay = 30
    
    init(db: Database, logger: Logger) {
        self.db = db
        self.logger = logger
    }
    
    // Проверка, можно ли постить ответ
    func canPost(to comment: Comment) async throws -> Bool {
        let now = Date()
        
        // 1. Проверка: уже отвечали на этот комментарий?
        if comment.replied {
            logger.warning("Already replied to this comment")
            return false
        }
        
        // 2. Проверка: не превышен ли лимит в час?
        let oneHourAgo = now.addingTimeInterval(-3600)
        let repliesLastHour = try await Reply.query(on: db)
            .filter(\.$postedAt > oneHourAgo)
            .count()
        
        if repliesLastHour >= maxRepliesPerHour {
            logger.warning("Hourly limit reached: \(repliesLastHour)/\(maxRepliesPerHour)")
            return false
        }
        
        // 3. Проверка: не превышен ли дневной лимит?
        let oneDayAgo = now.addingTimeInterval(-86400)
        let repliesToday = try await Reply.query(on: db)
            .filter(\.$postedAt > oneDayAgo)
            .count()
        
        if repliesToday >= maxRepliesPerDay {
            logger.warning("Daily limit reached: \(repliesToday)/\(maxRepliesPerDay)")
            return false
        }
        
        // 4. Проверка: прошло ли достаточно времени с последнего ответа?
        if let lastReply = try await Reply.query(on: db)
            .sort(\.$postedAt, .descending)
            .first() {
            
            if let lastPostedAt = lastReply.postedAt {
                let timeSinceLastPost = now.timeIntervalSince(lastPostedAt)
                if timeSinceLastPost < minTimeBetweenReplies {
                    logger.warning("Too soon since last post: \(Int(timeSinceLastPost))s")
                    return false
                }
            }
        }
        
        // 5. Проверка: не слишком ли много ответов в этом канале?
        let post = try await comment.$post.get(on: db)
        let channel = try await post.$channel.get(on: db)
        
        let repliesInChannel = try await Reply.query(on: db)
            .join(Comment.self, on: \Reply.$comment.$id == \Comment.$id)
            .join(Post.self, on: \Comment.$post.$id == \Post.$id)
            .filter(Post.self, \.$channel.$id == channel.requireID())
            .filter(\.$postedAt > oneDayAgo)
            .count()
        
        if repliesInChannel >= maxRepliesPerChannel {
            logger.warning("Channel daily limit reached: \(repliesInChannel)/\(maxRepliesPerChannel)")
            return false
        }
        
        return true
    }
    
    // Зарегистрировать новый ответ
    func recordPost(to comment: Comment) async throws {
        logger.info("📝 Recorded new reply in anti-spam system")
    }
}
```

### Шаг 9: Фоновые задачи (Jobs)

#### CommentAnalysisJob.swift
```swift
import Vapor
import Queues

struct CommentAnalysisJob: AsyncScheduledJob {
    let commentParser: CommentParserService
    let questionDetector: QuestionDetectorService
    let aiReplyService: AIReplyService
    let commentPoster: CommentPosterService
    
    // Запускать каждые 10 минут
    func run(context: QueueContext) async throws {
        context.logger.info("🔍 Starting comment analysis job...")
        
        // 1. Найти новые комментарии, которые ещё не обработаны
        let unprocessedComments = try await Comment.query(on: context.application.db)
            .filter(\.$replied == false)
            .filter(\.$is_question == false) // ещё не проверили
            .limit(50)
            .all()
        
        context.logger.info("📊 Found \(unprocessedComments.count) unprocessed comments")
        
        for comment in unprocessedComments {
            // 2. Определить, является ли это вопросом
            let isQuestion = questionDetector.isQuestion(comment.text)
            comment.isQuestion = isQuestion
            
            if !isQuestion {
                try await comment.save(on: context.application.db)
                continue
            }
            
            // 3. Найти ключевые слова
            let keywords = questionDetector.matchKeywords(comment.text)
            comment.keywordsMatched = keywords
            
            // 4. Рассчитать релевантность
            let relevance = questionDetector.calculateRelevance(comment.text)
            
            // 5. Если релевантность высокая (> 0.6), генерируем ответ
            if relevance > 0.6 {
                let post = try await comment.$post.get(on: context.application.db)
                let channel = try await post.$channel.get(on: context.application.db)
                
                let questionContext = QuestionContext(
                    category: questionDetector.detectCategory(comment.text),
                    channelName: channel.title,
                    postTopic: post.text.prefix(100).description,
                    keywordsMatched: keywords
                )
                
                // Генерируем ответ
                let replyText = try await aiReplyService.generateReply(
                    question: comment.text,
                    context: questionContext
                )
                
                // Создаём запись об ответе (но не публикуем сразу)
                let reply = Reply()
                reply.$comment.id = try comment.requireID()
                reply.generatedText = replyText
                reply.posted = false
                
                try await reply.save(on: context.application.db)
                
                context.logger.info("✅ Generated reply for comment \(comment.id?.uuidString ?? "unknown")")
            }
            
            try await comment.save(on: context.application.db)
        }
        
        context.logger.info("✅ Comment analysis job completed")
    }
}
```

#### ReplyPostingJob.swift
```swift
import Vapor
import Queues

struct ReplyPostingJob: AsyncScheduledJob {
    let commentPoster: CommentPosterService
    
    // Запускать каждые 15 минут
    func run(context: QueueContext) async throws {
        context.logger.info("📤 Starting reply posting job...")
        
        // 1. Найти сгенерированные, но не опубликованные ответы
        let pendingReplies = try await Reply.query(on: context.application.db)
            .filter(\.$posted == false)
            .limit(10)
            .all()
        
        context.logger.info("📊 Found \(pendingReplies.count) pending replies")
        
        for reply in pendingReplies {
            let comment = try await reply.$comment.get(on: context.application.db)
            
            do {
                // 2. Попытаться опубликовать
                try await commentPoster.postReply(
                    to: comment,
                    withText: reply.generatedText
                )
                
                context.logger.info("✅ Posted reply \(reply.id?.uuidString ?? "unknown")")
                
            } catch {
                context.logger.error("❌ Failed to post reply: \(error)")
                
                // Если ошибка, пометим как неудачную попытку
                // (можно добавить счётчик попыток)
            }
        }
        
        context.logger.info("✅ Reply posting job completed")
    }
}
```

### Шаг 10: Configuration

#### configure.swift
```swift
import Vapor
import Fluent
import FluentPostgresDriver
import Queues

public func configure(_ app: Application) async throws {
    // MARK: - Database
    guard let databaseURL = Environment.get("DATABASE_URL") else {
        fatalError("DATABASE_URL not set")
    }
    
    try app.databases.use(.postgres(url: databaseURL), as: .psql)
    
    // MARK: - Migrations
    app.migrations.add(CreateChannels())
    app.migrations.add(CreatePosts())
    app.migrations.add(CreateComments())
    app.migrations.add(CreateReplies())
    
    try await app.autoMigrate()
    
    // MARK: - Services
    let botToken = Environment.get("TELEGRAM_BOT_TOKEN")!
    let claudeApiKey = Environment.get("CLAUDE_API_KEY")!
    let botUsername = Environment.get("BOT_USERNAME") ?? "gdeTravel_bot"
    
    let telegramClient = TelegramClient(
        client: app.client,
        botToken: botToken,
        logger: app.logger
    )
    
    let questionDetector = QuestionDetectorService(logger: app.logger)
    
    let aiReplyService = AIReplyService(
        client: app.client,
        apiKey: claudeApiKey,
        botUsername: botUsername,
        logger: app.logger
    )
    
    let antiSpam = AntiSpamService(db: app.db, logger: app.logger)
    
    let commentPoster = CommentPosterService(
        telegramClient: telegramClient,
        antiSpam: antiSpam,
        db: app.db,
        logger: app.logger
    )
    
    // MARK: - Queues (фоновые задачи)
    try app.queues.use(.memory)
    
    // Анализ комментариев каждые 10 минут
    app.queues.schedule(
        CommentAnalysisJob(
            commentParser: CommentParserService(),
            questionDetector: questionDetector,
            aiReplyService: aiReplyService,
            commentPoster: commentPoster
        )
    )
    .minutely()
    .at(0, 10, 20, 30, 40, 50)
    
    // Публикация ответов каждые 15 минут
    app.queues.schedule(
        ReplyPostingJob(commentPoster: commentPoster)
    )
    .minutely()
    .at(5, 20, 35, 50)
    
    try app.queues.startScheduledJobs()
    
    // MARK: - Routes
    try routes(app)
}
```

### Шаг 11: Environment файл

#### .env.example
```bash
# Database
DATABASE_URL=postgres://user:password@localhost:5432/comment_bot

# Telegram
TELEGRAM_BOT_TOKEN=your_bot_token_here
BOT_USERNAME=gdeTravel_bot

# Claude AI
CLAUDE_API_KEY=your_claude_api_key_here

# Server
PORT=8080
LOG_LEVEL=info

# Monitoring
ENABLE_METRICS=true
```

---

## 🔒 Безопасность и анти-бан меры

### 1. Rate Limiting
```swift
// В AntiSpamService.swift уже реализовано:
- Максимум 5 ответов в час
- Максимум 30 ответов в день
- Минимум 5 минут между ответами
- Максимум 10 ответов на канал в день
```

### 2. Случайные задержки
```swift
// Выглядит естественнее
let delay = TimeInterval.random(in: 30...120) // 30-120 секунд
try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
```

### 3. Вариация текстов
```swift
// Добавить в AIReplyService вариации фраз
let botMentions = [
    "💡 Попробуйте @\(botUsername)",
    "🤖 Кстати, @\(botUsername) поможет",
    "✈️ Советую посмотреть @\(botUsername)",
    "📱 Ещё есть @\(botUsername) для таких задач"
]

let randomMention = botMentions.randomElement()!
return "\(generatedText)\n\n\(randomMention)"
```

### 4. Проверка на дубликаты
```swift
// В CommentAnalysisJob добавить проверку
let similarComments = try await Comment.query(on: db)
    .filter(\.$text == comment.text)
    .filter(\.$replied == true)
    .count()

if similarComments > 0 {
    continue // Пропускаем дубликат
}
```

---

## 🚀 Деплой

### Docker

#### Dockerfile
```dockerfile
FROM swift:5.9-jammy as build

WORKDIR /build

# Копируем зависимости
COPY Package.* ./
RUN swift package resolve

# Копируем исходники
COPY . .

# Собираем
RUN swift build -c release --static-swift-stdlib

# Production stage
FROM ubuntu:jammy

# Устанавливаем runtime зависимости
RUN apt-get update -y \
    && apt-get install -y libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем бинарник
COPY --from=build /build/.build/release/App ./

EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
```

#### docker-compose.yml
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://comment_bot:password@db:5432/comment_bot
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
      BOT_USERNAME: ${BOT_USERNAME}
      CLAUDE_API_KEY: ${CLAUDE_API_KEY}
    depends_on:
      - db
    restart: unless-stopped
    
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: comment_bot
      POSTGRES_USER: comment_bot
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

### Railway Deploy

```bash
# 1. Создать новый проект на Railway
railway init

# 2. Добавить PostgreSQL
railway add postgres

# 3. Настроить переменные окружения
railway variables set TELEGRAM_BOT_TOKEN=your_token
railway variables set CLAUDE_API_KEY=your_key
railway variables set BOT_USERNAME=gdeTravel_bot

# 4. Задеплоить
railway up
```

---

## 📊 Мониторинг

### API для статистики

#### routes.swift
```swift
import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req in
        return ["status": "ok"]
    }
    
    // Статистика
    app.get("stats") { req async throws -> StatsResponse in
        let totalChannels = try await Channel.query(on: req.db).count()
        let activeChannels = try await Channel.query(on: req.db)
            .filter(\.$isActive == true)
            .count()
        
        let totalComments = try await Comment.query(on: req.db).count()
        let questions = try await Comment.query(on: req.db)
            .filter(\.$isQuestion == true)
            .count()
        
        let totalReplies = try await Reply.query(on: req.db).count()
        let postedReplies = try await Reply.query(on: req.db)
            .filter(\.$posted == true)
            .count()
        
        let today = Date().addingTimeInterval(-86400)
        let repliesToday = try await Reply.query(on: req.db)
            .filter(\.$postedAt > today)
            .count()
        
        return StatsResponse(
            channels: ChannelStats(total: totalChannels, active: activeChannels),
            comments: CommentStats(total: totalComments, questions: questions),
            replies: ReplyStats(
                total: totalReplies,
                posted: postedReplies,
                today: repliesToday
            )
        )
    }
}

struct StatsResponse: Content {
    struct ChannelStats: Content {
        let total: Int
        let active: Int
    }
    
    struct CommentStats: Content {
        let total: Int
        let questions: Int
    }
    
    struct ReplyStats: Content {
        let total: Int
        let posted: Int
        let today: Int
    }
    
    let channels: ChannelStats
    let comments: CommentStats
    let replies: ReplyStats
}
```

---

## 📝 Финальный чеклист

### Перед запуском:

- [ ] Создать Telegram бота через @BotFather
- [ ] Получить токен Claude API
- [ ] Настроить PostgreSQL
- [ ] Добавить бота в целевые каналы (как администратора)
- [ ] Заполнить .env файл
- [ ] Запустить миграции БД
- [ ] Протестировать на 1-2 каналах
- [ ] Настроить мониторинг

### После запуска:

- [ ] Отслеживать метрики ответов
- [ ] Проверять качество ответов AI
- [ ] Корректировать лимиты анти-спама
- [ ] Добавлять новые паттерны вопросов
- [ ] Собирать feedback от пользователей

---

## 🎯 Следующие шаги

1. **Автоматический поиск каналов**
   ```swift
   // Реализовать ChannelDiscoveryService
   // Парсить Telegram по ключевым словам: "путешествия", "туризм"
   ```

2. **Sentiment Analysis**
   ```swift
   // Анализировать тональность вопросов
   // Отвечать только на позитивные/нейтральные
   ```

3. **A/B тестирование ответов**
   ```swift
   // Генерировать 2-3 варианта ответа
   // Выбирать лучший по метрикам
   ```

4. **Dashboard**
   ```typescript
   // Next.js админка для мониторинга
   // Графики, статистика, управление каналами
   ```

---

## 💡 Полезные ссылки

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Claude API Docs](https://docs.anthropic.com/)
- [Vapor Framework](https://docs.vapor.codes/)
- [Fluent ORM](https://docs.vapor.codes/fluent/overview/)

---

**Готово к разработке!** 🚀

Создавай новый репозиторий, копируй структуру и начинай кодить!

