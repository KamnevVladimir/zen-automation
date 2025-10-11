import Vapor

protocol TelegramNotifierProtocol {
    func sendNotification(message: String) async throws
    func sendPostPublished(post: ZenPostModel, images: Int) async throws
    func sendError(error: String) async throws
}

final class TelegramNotifier: TelegramNotifierProtocol {
    private let client: Client
    private let botToken: String
    private let chatId: String
    private let logger: Logger
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.botToken = AppConfig.telegramToken
        self.chatId = AppConfig.telegramAdminChatId
        self.logger = logger
    }
    
    func sendNotification(message: String) async throws {
        guard !botToken.isEmpty && !chatId.isEmpty else {
            logger.warning("Telegram credentials not configured")
            return
        }
        
        let url = URI(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body = TelegramSendMessage(
            chatId: chatId,
            text: message,
            parseMode: "HTML"
        )
        
        try request.content.encode(body)
        
        let response = try await client.send(request)
        
        if response.status != .ok {
            logger.error("Failed to send Telegram notification: \(response.status)")
        }
    }
    
    func sendPostPublished(post: ZenPostModel, images: Int) async throws {
        let shortPostCount = post.shortPost?.count ?? 0
        let fullPostCount = post.fullPost?.count ?? 0
        
        let message = """
        ✅ <b>Пост опубликован</b>
        
        📝 <b>Название:</b> \(post.title)
        🏷 <b>Тип:</b> \(post.templateType)
        🖼 <b>Изображений:</b> \(images)
        📊 <b>Символов:</b>
        • Короткий: \(shortPostCount)
        • Полный: \(fullPostCount)
        🏷 <b>Теги:</b> \(post.tags.joined(separator: ", "))
        
        🔗 <b>ID:</b> <code>\(post.id?.uuidString ?? "N/A")</code>
        """
        
        try await sendNotification(message: message)
    }
    
    func sendError(error: String) async throws {
        let message = """
        ❌ <b>Ошибка генерации</b>
        
        \(error)
        
        🕐 \(ISO8601DateFormatter().string(from: Date()))
        """
        
        try await sendNotification(message: message)
    }
}

// MARK: - Models

struct TelegramSendMessage: Content {
    let chatId: String
    let text: String
    let parseMode: String
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case parseMode = "parse_mode"
    }
}

