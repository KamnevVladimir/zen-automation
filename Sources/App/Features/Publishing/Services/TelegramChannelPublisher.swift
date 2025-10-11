import Vapor
import Fluent

/// Публикация в Telegram Channel (для импорта в Дзен)
final class TelegramChannelPublisher: ZenPublisherProtocol {
    private let client: Client
    private let botToken: String
    private let channelId: String // Например: @your_channel
    private let logger: Logger
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.botToken = AppConfig.telegramToken
        // Автоматически добавляем @ если его нет
        let rawChannelId = AppConfig.telegramChannelId
        self.channelId = rawChannelId.hasPrefix("@") ? rawChannelId : "@\(rawChannelId)"
        self.logger = logger
    }
    
    func publish(post: ZenPostModel, db: Database) async throws -> PublishResult {
        // Получаем изображения из БД
        let images = try await ZenImageModel.query(on: db)
            .filter(\.$post.$id == post.id!)
            .sort(\.$position)
            .all()
        
        return try await publishInternal(post: post, images: images, db: db)
    }
    
    private func publishInternal(post: ZenPostModel, images: [ZenImageModel], db: Database) async throws -> PublishResult {
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
        try await post.save(on: db)
        
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
        
        // Конвертируем Markdown в HTML для Telegram
        let htmlCaption = convertMarkdownToHTML(caption)
        
        let body: [String: Any] = [
            "chat_id": channelId,
            "photo": url,
            "caption": htmlCaption,
            "parse_mode": "HTML"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        logger.info("📤 Отправляю фото в Telegram: \(url)")
        logger.info("📦 Размер JSON payload: \(data.count) байт")
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Telegram API sendPhoto error!")
            logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
            logger.error("   Body: \(errorBody)")
            logger.error("   Photo URL: \(url)")
            logger.error("   Payload size: \(data.count) байт")
            throw Abort(.internalServerError, reason: "Telegram API error: \(response.status.code) \(response.status.reasonPhrase)")
        }
        
        logger.info("✅ Фото отправлено в Telegram")
    }
    
    private func sendMessage(text: String) async throws {
        let apiUrl = URI(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: apiUrl)
        request.headers.add(name: .contentType, value: "application/json")
        
        // Конвертируем Markdown в HTML для Telegram
        let htmlText = convertMarkdownToHTML(text)
        
        let body: [String: Any] = [
            "chat_id": channelId,
            "text": htmlText,
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
        // Telegram caption лимит: 1024 символа
        var caption = ""
        
        // Заголовок жирным с заглавной буквы
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        caption += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            caption += "\n\n\(subtitle)"
        }
        
        // Добавляем максимум текста (Telegram caption лимит 1024)
        caption += "\n\n\(post.body)"
        
        // Telegram обрежет автоматически на 1024, но на всякий случай
        if caption.count > 1020 {
            caption = String(caption.prefix(1020)) + "..."
        }
        
        return caption
    }
    
    private func formatMessage(post: ZenPostModel) -> String {
        // Telegram message лимит: 4096 символов
        var message = ""
        
        // Заголовок жирным с заглавной буквы
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        message += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            message += "\n\n\(subtitle)"
        }
        
        // Добавляем максимум текста (Telegram message лимит 4096)
        message += "\n\n\(post.body)"
        
        // Хештеги в конце
        message += "\n\n#путешествия #дешевыеполеты #отпуск"
        
        // Telegram обрежет автоматически на 4096
        if message.count > 4090 {
            message = String(message.prefix(4090)) + "..."
        }
        
        return message
    }
    
    /// Конвертирует Markdown (**bold**) в HTML (<b>bold</b>) для Telegram
    private func convertMarkdownToHTML(_ text: String) -> String {
        var result = text
        
        // 1. Сначала экранируем HTML символы (кроме < > для будущих тегов)
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        
        // 2. **bold** → <b>bold</b>
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<b>$1</b>",
            options: .regularExpression
        )
        
        // 3. Заменяем маркеры списков на точки
        result = result.replacingOccurrences(of: "⚡️ ", with: "• ")
        result = result.replacingOccurrences(of: "🎯 ", with: "• ")
        result = result.replacingOccurrences(of: "✈️ ", with: "• ")
        result = result.replacingOccurrences(of: "💰 ", with: "• ")
        result = result.replacingOccurrences(of: "📍 ", with: "• ")
        
        return result
    }
}

