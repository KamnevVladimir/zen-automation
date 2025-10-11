import Vapor
import Fluent

protocol ZenPublisherProtocol {
    func publish(post: ZenPostModel, db: Database) async throws -> PublishResult
}

struct PublishResult: Content {
    let success: Bool
    let zenArticleId: String?
    let publishedURL: String?
    let errorMessage: String?
}

final class ZenPublisher: ZenPublisherProtocol {
    private let logger: Logger
    private let notifier: TelegramNotifierProtocol
    
    init(logger: Logger, notifier: TelegramNotifierProtocol) {
        self.logger = logger
        self.notifier = notifier
    }
    
    func publish(post: ZenPostModel, db: Database) async throws -> PublishResult {
        logger.info("📤 Публикация поста: \(post.title)")
        
        // 1. Обновляем статус поста
        post.status = .published
        post.publishedAt = Date()
        post.zenArticleId = "zen_\(UUID().uuidString.prefix(12))"
        
        try await post.save(on: db)
        
        // 2. Получаем изображения
        let images = try await ZenImageModel.query(on: db)
            .filter(\.$post.$id == post.id!)
            .all()
        
        // 3. Формируем сообщение для Telegram с готовым постом
        let shortPostCount = post.shortPost?.count ?? 0
        let fullPostCount = post.fullPost?.count ?? 0
        let totalCount = shortPostCount + fullPostCount
        
        let message = """
        ✅ <b>Новый пост готов к публикации</b>
        
        📝 <b>Заголовок:</b> \(post.title)
        
        📊 <b>Статистика:</b>
        • Короткий пост (Telegram): \(shortPostCount) символов
        • Полный пост (Telegraph): \(fullPostCount) символов
        • Всего: \(totalCount) символов
        • Изображений: \(images.count)
        • Теги: \(post.tags.joined(separator: ", "))
        
        🔗 <b>Ссылки на изображения:</b>
        \(images.map { "• \($0.url)" }.joined(separator: "\n"))
        
        📄 <b>Короткий пост для Telegram:</b>
        
        <b>\(post.title)</b>
        
        \((post.shortPost ?? "").truncate(to: 500, addEllipsis: true))
        
        💡 <i>Полный текст будет опубликован в Telegraph</i>
        """
        
        // 4. Отправляем уведомление с готовым постом
        try await notifier.sendNotification(message: message)
        
        logger.info("✅ Пост готов, отправлено уведомление")
        
        return PublishResult(
            success: true,
            zenArticleId: post.zenArticleId,
            publishedURL: nil,
            errorMessage: nil
        )
    }
}

// MARK: - RSS Publisher (альтернатива)

final class RSSPublisher {
    func generateRSSFeed(posts: [ZenPostModel]) -> String {
        let rssItems = posts.map { post -> String in
            let description = post.shortPost ?? post.fullPost ?? ""
            return """
            <item>
                <title><![CDATA[\(post.title)]]></title>
                <description><![CDATA[\(description.prefix(500))...]]></description>
                <link>https://dzen.ru/article/\(post.zenArticleId ?? "")</link>
                <guid isPermaLink="false">\(post.id?.uuidString ?? "")</guid>
                <pubDate>\(formatRFC822Date(post.publishedAt ?? Date()))</pubDate>
            </item>
            """
        }.joined(separator: "\n")
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel>
                <title>Дешёвые путешествия</title>
                <link>https://t.me/gdeVacationBot</link>
                <description>Автоматические посты про бюджетные путешествия</description>
                <language>ru</language>
                <lastBuildDate>\(formatRFC822Date(Date()))</lastBuildDate>
                <atom:link href="https://your-domain.com/rss" rel="self" type="application/rss+xml" />
                \(rssItems)
            </channel>
        </rss>
        """
    }
    
    private func formatRFC822Date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

