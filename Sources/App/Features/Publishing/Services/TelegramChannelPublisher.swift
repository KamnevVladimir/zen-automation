import Vapor
import Fluent

/// Публикация в Telegram Channel (для импорта в Дзен)
final class TelegramChannelPublisher: ZenPublisherProtocol {
    private let client: Client
    private let botToken: String
    private let channelId: String // Например: @your_channel
    private let logger: Logger
    private let telegraphPublisher: TelegraphPublisherProtocol
    private let contentGenerator: ContentGeneratorServiceProtocol
    
    init(
        client: Client,
        logger: Logger,
        contentGenerator: ContentGeneratorServiceProtocol
    ) {
        self.client = client
        self.botToken = AppConfig.telegramToken
        // Автоматически добавляем @ если его нет
        let rawChannelId = AppConfig.telegramChannelId
        self.channelId = rawChannelId.hasPrefix("@") ? rawChannelId : "@\(rawChannelId)"
        self.logger = logger
        self.telegraphPublisher = TelegraphPublisher(client: client, logger: logger)
        self.contentGenerator = contentGenerator
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
            // 1. Создаём полный пост в Telegraph
            let fullContent = post.fullPost ?? formatFullContent(post: post)
            let telegraphURL = try await telegraphPublisher.createPage(
                title: post.title,
                content: fullContent,
                images: images
            )
            
            logger.info("✅ Telegraph страница создана: \(telegraphURL)")
            
            // 2. Используем короткий пост от AI + добавляем ссылку
            let shortContent = try await formatShortContentFromAI(post: post, telegraphURL: telegraphURL)
            
            // 3. Публикуем короткий пост с главным фото
            if let mainImage = images.first(where: { $0.position == 0 }) {
                logger.info("📸 Публикация: Фото + короткий пост (\(shortContent.count) символов)")
                try await sendPhoto(url: mainImage.url, caption: shortContent)
            } else {
                logger.info("📄 Публикация: Только короткий пост (\(shortContent.count) символов)")
                try await sendMessage(text: shortContent)
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
        
        // Telegram лимит для caption: 1024 символа
        let maxCaptionLength = 1024
        let finalCaption: String
        
        if htmlCaption.count > maxCaptionLength {
            logger.warning("⚠️ Caption слишком длинный (\(htmlCaption.count) символов), обрезаю до \(maxCaptionLength)")
            
            // Обрезаем до 1024 символов, но стараемся не разрывать слова
            let truncated = String(htmlCaption.prefix(maxCaptionLength))
            if let lastSpaceIndex = truncated.lastIndex(of: " ") {
                finalCaption = String(truncated[..<lastSpaceIndex]) + "..."
            } else {
                finalCaption = truncated + "..."
            }
            
            logger.info("📝 Итоговый caption: \(finalCaption.count) символов")
        } else {
            finalCaption = htmlCaption
        }
        
        let body: [String: Any] = [
            "chat_id": channelId,
            "photo": url,
            "caption": finalCaption,
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
    
    /// DEPRECATED: Используйте formatShortContentFromAI вместо этого
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
        
        // Используем shortPost если есть, иначе fullPost
        let content = post.shortPost ?? post.fullPost ?? ""
        if maxBodyLength > 100 && !content.isEmpty {
            let bodyPreview = smartTruncate(content, maxLength: maxBodyLength)
        caption += "\n\n\(bodyPreview)"
        }
        
        return caption
    }
    
    /// Форматирует полный контент для публикации (весь текст)
    /// DEPRECATED: Эта функция больше не нужна, т.к. AI генерирует fullPost
    private func formatFullContent(post: ZenPostModel) -> String {
        // Если fullPost отсутствует - это ошибка генерации
        // Возвращаем только заголовок + предупреждение
        var content = ""
        
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        content += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            let sub = subtitle.prefix(1).uppercased() + subtitle.dropFirst()
            content += "\n\n\(sub)"
        }
        
        content += "\n\n⚠️ Полный текст не сгенерирован. Обратитесь к администратору."
        
        return content
    }
    
    /// Форматирует короткий пост от AI + добавляет ссылку на Telegraph
    ///
    /// ВАЖНО: По документации Дзена (https://dzen.ru/help/ru/channel/cross-platform.html):
    /// - Первое предложение (до точки) = заголовок в Дзене (макс 140 символов)
    /// - Форматирование из Telegram НЕ переносится в Дзен
    /// - Первая картинка = обложка статьи
    private func formatShortContentFromAI(post: ZenPostModel, telegraphURL: String) async throws -> String {
        // AI уже генерирует короткий пост с правильной структурой:
        // Первое предложение = заголовок для Дзена
        guard var aiShortPost = post.shortPost, !aiShortPost.isEmpty else {
            // Если shortPost пустой - ошибка генерации
            return "⚠️ Ошибка: короткий пост не сгенерирован\n\n📖 Читать полную статью:\n\(telegraphURL)"
        }
        
        // Добавляем ссылку на бота и полную статью
        // ОПТИМИЗАЦИЯ ДЛЯ ЯНДЕКС ДЗЕНА: простые ссылки без Markdown
        let botLink = "🤖 @gdeVacationBot - поиск дешёвых билетов"
        let fullArticleLink = "📖 Полная статья: \(telegraphURL)"
        
        // Рассчитываем РЕАЛЬНУЮ длину ссылок (Telegraph URL может быть очень длинным!)
        let linksText = "\n\n\(botLink)\n\(fullArticleLink)"
        let linksLength = linksText.count
        
        logger.info("📏 Длина ссылок: \(linksLength) символов (бот: ~85, telegraph: ~\(fullArticleLink.count))")
        
        // Telegram лимит для caption: 1024 символа
        // Целевой размер: 900-1000 символов (по требованию пользователя)
        let maxCaptionLength = 1024
        // ВАЖНО: вычитаем РЕАЛЬНУЮ длину ссылок, а не предполагаемую 200
        let targetContentLength = maxCaptionLength - linksLength - 20 // -20 на запас
        let minContentLength = 900 - linksLength
        
        // Проверяем, нужно ли пересоздать короткий пост
        var attempts = 0
        let maxAttempts = 3
        
        while aiShortPost.count + linksLength > maxCaptionLength && attempts < maxAttempts {
            attempts += 1
            logger.warning("⚠️ ShortPost слишком длинный (\(aiShortPost.count + linksLength) символов > \(maxCaptionLength))")
            logger.info("🔄 Попытка \(attempts)/\(maxAttempts): Запрашиваю у Claude более короткий вариант...")
            
            // Запрашиваем у Claude более короткий вариант
            let fullPost = post.fullPost ?? ""
            aiShortPost = try await contentGenerator.regenerateShortPost(
                fullPost: fullPost,
                currentShortPost: aiShortPost,
                targetLength: targetContentLength
            )
            
            // Сохраняем обновлённый shortPost в БД
            post.shortPost = aiShortPost
        }
        
        // Финальная проверка
        let finalContentLength = aiShortPost.count + linksLength
        
        if finalContentLength > maxCaptionLength {
            logger.error("❌ Не удалось уместить контент в \(maxCaptionLength) символов после \(attempts) попыток")
            logger.error("   Итоговая длина: \(finalContentLength) символов")
            throw Abort(.badRequest, reason: "Контент слишком длинный даже после \(attempts) пересозданий")
        }
        
        if finalContentLength < minContentLength {
            logger.warning("⚠️ Контент короче целевого (\(finalContentLength) < \(minContentLength))")
        }
        
        // Итоговый контент
        let content = aiShortPost + linksText
        
        logger.info("✅ Итоговый short content: \(content.count) символов (цель: 900-1000, лимит: \(maxCaptionLength))")
        
        return content
    }
    
    /// DEPRECATED: Используйте formatShortContentFromAI вместо этого
    /// Форматирует короткий контент для Telegram (500-800 символов + ссылка на Telegraph)
    private func formatShortContent(post: ZenPostModel, telegraphURL: String) -> String {
        var content = ""
        
        // Начало с призыва прочитать подробную статью
        content += "📖 Читайте подробную статью со всеми деталями в нашем Telegraph канале:\n\n"
        
        // Заголовок жирным с заглавной буквы
        let title = post.title.prefix(1).uppercased() + post.title.dropFirst()
        content += "**\(title)**"
        
        if let subtitle = post.subtitle, !subtitle.isEmpty {
            let sub = subtitle.prefix(1).uppercased() + subtitle.dropFirst()
            content += "\n\n\(sub)"
        }
        
        // Используем fullPost для preview
        let fullContent = post.fullPost ?? ""
        let maxBodyLength = 450 // Оставляем место для ссылки в конце
        let bodyPreview = smartTruncate(fullContent, maxLength: maxBodyLength)
        content += "\n\n\(bodyPreview)"
        
        // Хештеги
        content += "\n\n#путешествия #дешевыеполеты #отпуск"
        
        // Конец с призывом прочитать полную статью
        content += "\n\n📖 Подробная статья со всеми деталями:\n\(telegraphURL)"
        
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
        
        // 4. Экранируем оставшиеся < > символы (кроме уже созданных тегов)
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        
        // 5. Восстанавливаем наши HTML теги
        result = result.replacingOccurrences(of: "&lt;b&gt;", with: "<b>")
        result = result.replacingOccurrences(of: "&lt;/b&gt;", with: "</b>")
        
        return result
    }
}

