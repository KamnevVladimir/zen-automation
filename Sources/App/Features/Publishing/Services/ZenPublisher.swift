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
        
        // TODO: Интеграция с Яндекс Дзен API
        // Пока что просто симулируем успешную публикацию
        
        // 1. Обновляем статус поста
        post.status = .published
        post.publishedAt = Date()
        post.zenArticleId = "zen_\(UUID().uuidString.prefix(12))"
        
        try await post.save(on: db)
        
        // 2. Получаем количество изображений
        let imagesCount = try await ZenImageModel.query(on: db)
            .filter(\.$post.$id == post.id!)
            .count()
        
        // 3. Отправляем уведомление
        try await notifier.sendPostPublished(post: post, images: imagesCount)
        
        logger.info("✅ Пост опубликован: \(post.zenArticleId ?? "N/A")")
        
        return PublishResult(
            success: true,
            zenArticleId: post.zenArticleId,
            publishedURL: "https://dzen.ru/id/\(post.zenArticleId ?? "")",
            errorMessage: nil
        )
    }
}

// MARK: - RSS Publisher (альтернатива)

final class RSSPublisher {
    func generateRSSFeed(posts: [ZenPostModel]) -> String {
        let rssItems = posts.map { post -> String in
            """
            <item>
                <title><![CDATA[\(post.title)]]></title>
                <description><![CDATA[\(post.body.prefix(500))...]]></description>
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

