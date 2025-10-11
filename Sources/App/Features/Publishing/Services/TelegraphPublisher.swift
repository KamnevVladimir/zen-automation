import Vapor
import Foundation

/// Сервис для публикации постов в Telegraph
final class TelegraphPublisher: TelegraphPublisherProtocol {
    private let client: Client
    private let logger: Logger
    
    private let baseURL = "https://api.telegra.ph"
    private var accessToken: String?
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    /// Создаёт аккаунт Telegraph и возвращает access_token
    private func createAccount() async throws -> String {
        logger.info("🔐 Создание аккаунта Telegraph...")
        
        let url = URI(string: "\(baseURL)/createAccount")
        
        let requestBody: [String: Any] = [
            "short_name": "GdeTravel",
            "author_name": "GdeTravel",
            "author_url": "https://t.me/gdeTravel"
        ]
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        request.body = .init(data: try JSONSerialization.data(withJSONObject: requestBody))
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Telegraph createAccount error: \(response.status)")
            logger.error("   Response: \(errorBody)")
            throw Abort(.badRequest, reason: "Telegraph createAccount error")
        }
        
        struct CreateAccountResponse: Codable {
            let ok: Bool
            let result: AccountResult
            
            struct AccountResult: Codable {
                let short_name: String
                let author_name: String
                let author_url: String?
                let access_token: String
                let auth_url: String?
            }
        }
        
        let accountResponse = try response.content.decode(CreateAccountResponse.self)
        
        if accountResponse.ok {
            logger.info("✅ Telegraph аккаунт создан, access_token получен")
            return accountResponse.result.access_token
        } else {
            throw Abort(.badRequest, reason: "Failed to create Telegraph account")
        }
    }
    
    /// Получает или создаёт access_token
    private func getAccessToken() async throws -> String {
        // Если токен уже есть - используем его
        if let token = accessToken {
            return token
        }
        
        // Создаём новый аккаунт
        let token = try await createAccount()
        accessToken = token
        
        return token
    }
    
    /// Конвертирует Telegram file_id в прямую ссылку на файл
    private func convertTelegramFileIdToUrl(fileId: String) -> String {
        // Telegram file_id нужно конвертировать в прямую ссылку через getFile API
        // Пока что возвращаем как есть - Telegraph может не поддерживать Telegram URLs
        // В будущем можно добавить вызов getFile API для получения прямой ссылки
        return fileId
    }
    
    /// Создаёт страницу в Telegraph и возвращает URL
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String {
        logger.info("📝 Создание страницы в Telegraph: \(title)")
        
        // Получаем или создаём access_token
        let token = try await getAccessToken()
        
        // Конвертируем Markdown в HTML-массив для Telegraph
        let htmlArray = convertToTelegraphHTMLArray(content: content, images: images)
        
        let url = URI(string: "\(baseURL)/createPage")
        
        let requestBody: [String: Any] = [
            "access_token": token,
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
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Telegraph API error: \(response.status)")
            logger.error("   Response body: \(errorBody)")
            throw Abort(.badRequest, reason: "Telegraph API error: \(response.status)")
        }
        
        // Логируем тело ответа для диагностики
        let bodyString = response.body.map { String(buffer: $0) } ?? "{}"
        logger.info("📥 Telegraph response: \(bodyString.prefix(1000))")
        
        // Структуры для парсинга
        struct TelegraphResponseSuccess: Codable {
            let ok: Bool
            let result: TelegraphPage
        }
        
        struct TelegraphResponseError: Codable {
            let ok: Bool
            let error: String
        }
        
        struct TelegraphPage: Codable {
            let path: String
            let url: String
            let title: String
        }
        
        // Сначала проверяем на ошибку
        if let errorResponse = try? response.content.decode(TelegraphResponseError.self), !errorResponse.ok {
            logger.error("❌ Telegraph API error: \(errorResponse.error)")
            throw Abort(.badRequest, reason: "Telegraph API error: \(errorResponse.error)")
        }
        
        // Парсим успешный ответ
        let successResponse = try response.content.decode(TelegraphResponseSuccess.self)
        
        guard successResponse.ok else {
            throw Abort(.badRequest, reason: "Telegraph returned ok=false")
        }
        
        logger.info("✅ Telegraph страница создана: \(successResponse.result.url)")
        return successResponse.result.url
    }
    
    /// Конвертирует Markdown контент в HTML-массив для Telegraph API
    private func convertToTelegraphHTMLArray(content: String, images: [ZenImageModel]) -> [[String: Any]] {
        var htmlArray: [[String: Any]] = []
        
        // 1. СНАЧАЛА добавляем главное изображение
        if let mainImage = images.first(where: { $0.position == 0 }) {
            // Конвертируем Telegram file_id в прямую ссылку
            let imageUrl = convertTelegramFileIdToUrl(fileId: mainImage.url)
            htmlArray.append([
                "tag": "figure",
                "children": [
                    [
                        "tag": "img",
                        "attrs": [
                            "src": imageUrl,
                            "alt": "Главное изображение"
                        ]
                    ]
                ]
            ])
        }
        
        // 2. Обрабатываем контент
        var processedContent = content
        
        // Заменяем **жирный** на <b>жирный</b>
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*", options: [])
        let range = NSRange(location: 0, length: processedContent.utf16.count)
        processedContent = boldRegex.stringByReplacingMatches(in: processedContent, options: [], range: range, withTemplate: "<b>$1</b>")
        
        // Заменяем эмодзи маркеры на HTML списки (убираем эмодзи, оставляем bullet points)
        processedContent = processedContent.replacingOccurrences(of: "⚡️ ", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "🎯 ", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "✈️ ", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "💰 ", with: "<br>• ")
        processedContent = processedContent.replacingOccurrences(of: "📍 ", with: "<br>• ")
        
        // Заменяем переносы строк на <br>
        processedContent = processedContent.replacingOccurrences(of: "\n", with: "<br>")
        
        // 3. Добавляем текст как HTML элемент
        htmlArray.append([
            "tag": "p",
            "children": [processedContent]
        ])
        
        // 4. Добавляем остальные изображения в конце (если есть)
        let additionalImages = images.filter { $0.position != 0 }
        for (index, image) in additionalImages.enumerated() {
            htmlArray.append([
                "tag": "figure",
                "children": [
                    [
                        "tag": "img",
                        "attrs": [
                            "src": image.url,
                            "alt": "Изображение \(index + 2)"
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
