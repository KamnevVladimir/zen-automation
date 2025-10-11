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
        
        // Конвертируем Markdown в HTML-массив для Telegraph
        let htmlArray = convertToTelegraphHTMLArray(content: content, images: images)
        
        let url = URI(string: "\(baseURL)/createPage")
        
        let requestBody: [String: Any] = [
            "title": title,
            "content": htmlArray,
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
    
    /// Конвертирует Markdown контент в HTML-массив для Telegraph API
    private func convertToTelegraphHTMLArray(content: String, images: [ZenImageModel]) -> [[String: Any]] {
        var htmlArray: [[String: Any]] = []
        
        // Обрабатываем контент
        var processedContent = content
        
        // Заменяем **жирный** на <b>жирный</b>
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*", options: [])
        let range = NSRange(location: 0, length: processedContent.utf16.count)
        processedContent = boldRegex.stringByReplacingMatches(in: processedContent, options: [], range: range, withTemplate: "<b>$1</b>")
        
        // Заменяем эмодзи маркеры на HTML списки
        processedContent = processedContent.replacingOccurrences(of: "⚡️", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "🎯", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "✈️", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "💰", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "📍", with: "<br>• ")
        
        // Заменяем переносы строк на <br>
        processedContent = processedContent.replacingOccurrences(of: "\n", with: "<br>")
        
        // Добавляем текст как HTML элемент
        htmlArray.append([
            "tag": "p",
            "children": [processedContent]
        ])
        
        // Добавляем изображения
        for (index, image) in images.enumerated() {
            htmlArray.append([
                "tag": "figure",
                "children": [
                    [
                        "tag": "img",
                        "attrs": [
                            "src": image.url,
                            "alt": "Изображение \(index + 1)"
                        ]
                    ]
                ]
            ])
        }
        
        return htmlArray
    }
}

/// Протокол для публикации в Telegraph
protocol TelegraphPublisherProtocol {
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String
}
