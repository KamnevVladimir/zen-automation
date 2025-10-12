import Vapor
import Foundation
import NIO

/// Веб-скрапер для поиска постов и комментариев на Яндекс Дзене
final class ZenWebScraper {
    private let client: Client
    private let logger: Logger
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    /// Поиск постов по ключевым словам
    func searchPosts(keywords: [String], limit: Int = 10) async throws -> [ZenPostTarget] {
        logger.info("🔍 Ищу посты по ключевым словам: \(keywords.joined(separator: ", "))")
        
        var posts: [ZenPostTarget] = []
        
        for keyword in keywords.prefix(3) { // Ограничиваем количество запросов
            do {
                let searchResults = try await searchPostsByKeyword(keyword)
                posts.append(contentsOf: searchResults)
                
                // Пауза между запросами (избегаем блокировки)
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 секунды
                
            } catch {
                logger.warning("⚠️ Ошибка поиска по ключевому слову '\(keyword)': \(error)")
            }
        }
        
        // Убираем дубликаты и сортируем по количеству комментариев
        let uniquePosts = Array(Set(posts))
            .sorted { $0.commentCount > $1.commentCount }
            .prefix(limit)
        
        logger.info("✅ Найдено \(uniquePosts.count) уникальных постов")
        
        return Array(uniquePosts)
    }
    
    /// Поиск постов по конкретному ключевому слову
    private func searchPostsByKeyword(_ keyword: String) async throws -> [ZenPostTarget] {
        // URL для поиска на Яндекс Дзене
        let searchUrl = "https://zen.yandex.ru/search?query=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)"
        
        var request = ClientRequest(method: .GET, url: URI(string: searchUrl))
        request.headers.add(name: .userAgent, value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
        request.headers.add(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.badRequest, reason: "Ошибка поиска на Дзене: \(response.status)")
        }
        
        let body = response.body.map { String(buffer: $0) } ?? ""
        
        // Парсим HTML и извлекаем посты
        return try parsePostsFromHTML(body, keyword: keyword)
    }
    
    /// Парсинг HTML для извлечения постов
    private func parsePostsFromHTML(_ html: String, keyword: String) throws -> [ZenPostTarget] {
        var posts: [ZenPostTarget] = []
        
        // Простой парсинг HTML (в реальном проекте лучше использовать SwiftSoup)
        let postPattern = #"<a[^>]*href="([^"]*zen\.yandex\.ru[^"]*)"[^>]*>([^<]*)</a>"#
        let regex = try NSRegularExpression(pattern: postPattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        
        for match in matches.prefix(5) { // Ограничиваем количество
            if let urlRange = Range(match.range(at: 1), in: html),
               let titleRange = Range(match.range(at: 2), in: html) {
                
                let url = String(html[urlRange])
                let title = String(html[titleRange])
                
                // Проверяем, что это действительно пост о путешествиях
                if isTravelRelated(title) {
                    let post = ZenPostTarget(
                        url: url,
                        title: title,
                        author: "Unknown", // Можно извлечь из HTML
                        commentCount: 0, // Можно извлечь из HTML
                        keywords: [keyword]
                    )
                    posts.append(post)
                }
            }
        }
        
        return posts
    }
    
    /// Проверка, относится ли пост к путешествиям
    private func isTravelRelated(_ title: String) -> Bool {
        let travelKeywords = [
            "путешествие", "отпуск", "отдых", "туризм", "билеты",
            "отель", "виза", "паспорт", "самолет", "поезд",
            "страна", "город", "море", "горы", "пляж"
        ]
        
        let lowercaseTitle = title.lowercased()
        return travelKeywords.contains { lowercaseTitle.contains($0) }
    }
    
    /// Поиск комментариев к посту
    func getComments(from postUrl: String) async throws -> [CommentQuestion] {
        logger.info("💬 Получаю комментарии к посту: \(postUrl)")
        
        var request = ClientRequest(method: .GET, url: URI(string: postUrl))
        request.headers.add(name: .userAgent, value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
        request.headers.add(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.badRequest, reason: "Ошибка получения поста: \(response.status)")
        }
        
        let body = response.body.map { String(buffer: $0) } ?? ""
        
        // Парсим комментарии
        return try parseCommentsFromHTML(body, postUrl: postUrl)
    }
    
    /// Парсинг комментариев из HTML
    private func parseCommentsFromHTML(_ html: String, postUrl: String) throws -> [CommentQuestion] {
        var comments: [CommentQuestion] = []
        
        // Простой парсинг комментариев (в реальном проекте лучше использовать SwiftSoup)
        let commentPattern = #"<div[^>]*class="[^"]*comment[^"]*"[^>]*>([^<]*)</div>"#
        let regex = try NSRegularExpression(pattern: commentPattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        
        for (index, match) in matches.enumerated() {
            if let textRange = Range(match.range(at: 1), in: html) {
                let text = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Проверяем, является ли комментарий вопросом
                if isQuestion(text) {
                    let comment = CommentQuestion(
                        id: "comment_\(index)",
                        text: text,
                        author: "User_\(index)",
                        postUrl: postUrl,
                        timestamp: Date(),
                        isAnswered: false
                    )
                    comments.append(comment)
                }
            }
        }
        
        return comments
    }
    
    /// Проверка, является ли текст вопросом
    private func isQuestion(_ text: String) -> Bool {
        let questionWords = ["?", "как", "где", "что", "когда", "почему", "сколько", "можно ли"]
        let lowercaseText = text.lowercased()
        return questionWords.contains { lowercaseText.contains($0) }
    }
}

// MARK: - Расширения

extension ZenWebScraper: ZenEngagementServiceProtocol {
    func findPostsForCommenting(keywords: [String]) async throws -> [ZenPostTarget] {
        return try await searchPosts(keywords: keywords, limit: 10)
    }
    
    func findQuestionsInComments(postUrl: String) async throws -> [CommentQuestion] {
        return try await getComments(from: postUrl)
    }
    
    func generateSmartResponse(to question: CommentQuestion) async throws -> String {
        // Заглушка - в реальном проекте здесь будет вызов AI
        return "Спасибо за вопрос! Рекомендую изучить детали в нашем канале @gdeVacationBot"
    }
    
    func postComment(to postUrl: String, comment: String) async throws -> Bool {
        // Заглушка - в реальном проекте здесь будет отправка комментария
        logger.info("💬 Отправляю комментарий: \(comment)")
        return true
    }
    
    func analyzeEngagement() async throws -> EngagementStats {
        return EngagementStats(
            totalComments: 0,
            helpfulResponses: 0,
            newSubscribers: 0,
            engagementRate: 0.0
        )
    }
}
