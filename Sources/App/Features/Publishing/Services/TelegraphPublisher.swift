import Vapor
import Foundation

/// Сервис для публикации постов в Telegraph
final class TelegraphPublisher {
    private let client: Client
    private let logger: Logger
    
    private let baseURL = "https://api.telegra.ph"
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    /// Создаёт страницу в Telegraph и возвращает URL
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String {
        logger.info("📝 Создание страницы в Telegraph: \(title)")
        
        // Конвертируем Markdown в HTML для Telegraph
        let htmlContent = convertToTelegraphHTML(content: content, images: images)
        
        let url = URI(string: "\(baseURL)/createPage")
        
        let requestBody: [String: Any] = [
            "title": title,
            "content": htmlContent,
            "author_name": "GdeTravel",
            "author_url": "https://t.me/gdeTravel"
        ]
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        request.body = .init(data: try JSONSerialization.data(withJSONObject: requestBody))
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            logger.error("❌ Telegraph API error: \(response.status)")
            throw Abort(.badRequest, reason: "Telegraph API error: \(response.status)")
        }
        
        struct TelegraphResponse: Codable {
            let ok: Bool
            let result: TelegraphPage
            
            struct TelegraphPage: Codable {
                let path: String
                let url: String
                let title: String
            }
        }
        
        let telegraphResponse = try response.content.decode(TelegraphResponse.self)
        
        if telegraphResponse.ok {
            logger.info("✅ Telegraph страница создана: \(telegraphResponse.result.url)")
            return telegraphResponse.result.url
        } else {
            throw Abort(.badRequest, reason: "Failed to create Telegraph page")
        }
    }
    
    /// Конвертирует Markdown контент в HTML для Telegraph
    private func convertToTelegraphHTML(content: String, images: [ZenImageModel]) -> String {
        var html = content
        
        // Заменяем **жирный** на <b>жирный</b>
        html = html.replacingOccurrences(of: "**([^*]+)**", with: "<b>$1</b>", options: .regularExpression)
        
        // Заменяем эмодзи маркеры на HTML списки
        html = html.replacingOccurrences(of: "⚡️", with: "<br>• ")
        html = html.replacingOccurrences(of: "🎯", with: "<br>• ")
        html = html.replacingOccurrences(of: "✈️", with: "<br>• ")
        html = html.replacingOccurrences(of: "💰", with: "<br>• ")
        html = html.replacingOccurrences(of: "📍", with: "<br>• ")
        
        // Заменяем переносы строк на <br>
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // Добавляем изображения в HTML
        var imagesHTML = ""
        for (index, image) in images.enumerated() {
            imagesHTML += "<img src=\"\(image.url)\" alt=\"Изображение \(index + 1)\"><br><br>"
        }
        
        // Вставляем изображения в начало контента
        if !imagesHTML.isEmpty {
            html = imagesHTML + html
        }
        
        return html
    }
}

/// Протокол для публикации в Telegraph
protocol TelegraphPublisherProtocol {
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String
}
