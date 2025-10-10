import Vapor
import Fluent

/// Публикация в Telegram Channel (для импорта в Дзен)
final class TelegramChannelPublisher {
    private let client: Client
    private let botToken: String
    private let channelId: String // Например: @your_channel
    private let logger: Logger
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.botToken = AppConfig.telegramToken
        self.channelId = AppConfig.telegramChannelId
        self.logger = logger
    }
    
    func publish(post: ZenPostModel, images: [ZenImageModel]) async throws -> PublishResult {
        logger.info("📤 Публикация в Telegram канал: \(channelId)")
        
        do {
            // 1. Публикуем основное изображение (если есть)
            if let mainImage = images.first(where: { $0.position == 0 }) {
                try await sendPhoto(url: mainImage.url, caption: formatCaption(post: post))
            } else {
                // Если нет изображения - просто текст
                try await sendMessage(text: formatMessage(post: post))
            }
            
            // 2. Обновляем статус поста
            post.status = .published
            post.publishedAt = Date()
            post.zenArticleId = "tg_\(UUID().uuidString.prefix(12))"
            
            logger.info("✅ Пост опубликован в Telegram: \(post.title)")
            
            return PublishResult(
                success: true,
                zenArticleId: post.zenArticleId,
                publishedURL: "https://t.me/\(channelId.replacingOccurrences(of: "@", with: ""))",
                errorMessage: nil
            )
            
        } catch {
            logger.error("❌ Ошибка публикации в Telegram: \(error)")
            return PublishResult(
                success: false,
                zenArticleId: nil,
                publishedURL: nil,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    private func sendPhoto(url: String, caption: String) async throws {
        let apiUrl = URI(string: "https://api.telegram.org/bot\(botToken)/sendPhoto")
        
        var request = ClientRequest(method: .POST, url: apiUrl)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "chat_id": channelId,
            "photo": url,
            "caption": caption.truncate(to: 1024, addEllipsis: true),
            "parse_mode": "HTML"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Telegram API error: \(response.status)")
        }
    }
    
    private func sendMessage(text: String) async throws {
        let apiUrl = URI(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: apiUrl)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "chat_id": channelId,
            "text": text.truncate(to: 4096, addEllipsis: true),
            "parse_mode": "HTML",
            "disable_web_page_preview": false
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Telegram API error: \(response.status)")
        }
    }
    
    private func formatCaption(post: ZenPostModel) -> String {
        """
        <b>\(post.title)</b>
        
        \(post.subtitle ?? "")
        
        \(post.body.truncate(to: 800, addEllipsis: true))
        
        🔗 Подробнее в @\(AppConfig.botUsername)
        """
    }
    
    private func formatMessage(post: ZenPostModel) -> String {
        """
        <b>\(post.title)</b>
        
        \(post.subtitle ?? "")
        
        \(post.body.truncate(to: 3800, addEllipsis: true))
        
        🔗 Подробнее в @\(AppConfig.botUsername)
        
        #путешествия #дешевыеполеты #отпуск
        """
    }
}

