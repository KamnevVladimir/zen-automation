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
            // Форматируем полный контент
            let fullContent = formatFullContent(post: post)
            
            logger.info("📝 Общая длина контента: \(fullContent.count) символов")
            
            // 1. Публикуем основное изображение с caption (первые 1024 символа)
            if let mainImage = images.first(where: { $0.position == 0 }) {
                let caption = formatCaption(post: post)
                logger.info("📸 Сообщение 1/?: Фото + Caption (\(caption.count) символов)")
                try await sendPhoto(url: mainImage.url, caption: caption)
                
                // 2. Если контент длиннее caption - отправляем продолжение текстом
                let captionAfterMarkdown = convertMarkdownToHTML(caption).count
                if fullContent.count > captionAfterMarkdown {
                    let remainingContent = String(fullContent.dropFirst(captionAfterMarkdown))
                    
                    // Отправляем по частям если нужно (Telegram лимит 4096)
                    let chunks = splitIntoChunks(remainingContent, maxLength: 4000)
                    logger.info("📄 Продолжение разбито на \(chunks.count) частей")
                    
                    for (index, chunk) in chunks.enumerated() {
                        logger.info("📄 Сообщение \(index + 2)/\(chunks.count + 1): Текст (\(chunk.count) символов)")
                        try await sendMessage(text: chunk)
                        // Небольшая пауза между сообщениями
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 сек
                    }
                    
                    logger.info("✅ Опубликовано \(chunks.count + 1) сообщений (1 фото + \(chunks.count) текстов)")
                } else {
                    logger.info("✅ Весь контент поместился в caption")
                }
            } else {
                // Если нет изображения - отправляем только текст по частям
                let chunks = splitIntoChunks(fullContent, maxLength: 4000)
                logger.info("📄 Контент без фото, разбит на \(chunks.count) частей")
                
                for (index, chunk) in chunks.enumerated() {
                    logger.info("📄 Сообщение \(index + 1)/\(chunks.count): Текст (\(chunk.count) символов)")
                    try await sendMessage(text: chunk)
                    if chunks.count > 1 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 сек
                    }
                }
                
                logger.info("✅ Опубликовано \(chunks.count) текстовых сообщений")
            }
            
        // 3. Обновляем статус поста
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
        // Telegram caption СТРОГИЙ лимит: 1024 символа
        var caption = ""
        
        // Заголовок жирным с заглавной буквы
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        caption += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            let sub = subtitle.prefix(1).uppercased() + subtitle.dropFirst()
            caption += "\n\n\(sub)"
        }
        
        // Считаем сколько символов уже занято
        let headerLength = caption.count + 4 // +4 на \n\n
        let maxBodyLength = 1024 - headerLength - 10 // -10 на ... и запас
        
        // Добавляем начало body (умно обрезаем по предложениям)
        if maxBodyLength > 100 {
            let bodyPreview = smartTruncate(post.body, maxLength: maxBodyLength)
            caption += "\n\n\(bodyPreview)"
        }
        
        return caption
    }
    
    /// Форматирует полный контент для публикации (весь текст)
    private func formatFullContent(post: ZenPostModel) -> String {
        var content = ""
        
        // Заголовок жирным с заглавной буквы
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        content += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            let sub = subtitle.prefix(1).uppercased() + subtitle.dropFirst()
            content += "\n\n\(sub)"
        }
        
        // Весь body
        content += "\n\n\(post.body)"
        
        // Хештеги в конце
        content += "\n\n#путешествия #дешевыеполеты #отпуск"
        
        return content
    }
    
    /// Разбивает текст на части по maxLength, умно (по предложениям)
    private func splitIntoChunks(_ text: String, maxLength: Int) -> [String] {
        if text.count <= maxLength {
            return [text]
        }
        
        var chunks: [String] = []
        var remaining = text
        
        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }
            
            // Берём кусок с запасом
            let chunk = String(remaining.prefix(maxLength - 3))
            
            // Ищем последнюю точку, восклицательный или вопросительный знак
            if let lastSentenceEnd = chunk.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                let chunkText = String(chunk[...lastSentenceEnd])
                chunks.append(chunkText)
                remaining = String(remaining.dropFirst(chunkText.count))
            } else if let lastSpace = chunk.lastIndex(of: " ") {
                // Если нет - обрезаем по последнему пробелу
                let chunkText = String(chunk[...lastSpace])
                chunks.append(chunkText)
                remaining = String(remaining.dropFirst(chunkText.count))
            } else {
                // В крайнем случае - просто обрезаем
                chunks.append(chunk)
                remaining = String(remaining.dropFirst(chunk.count))
            }
            
            // Убираем пробелы в начале следующего куска
            remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return chunks
    }
    
    /// Умное обрезание текста по последнему полному предложению
    private func smartTruncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        
        // Обрезаем с запасом
        let truncated = String(text.prefix(maxLength - 3))
        
        // Ищем последнюю точку, восклицательный или вопросительный знак
        if let lastSentenceEnd = truncated.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
            return String(truncated[...lastSentenceEnd])
        }
        
        // Если нет - обрезаем по последнему пробелу
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[...lastSpace]) + "..."
        }
        
        return truncated + "..."
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

