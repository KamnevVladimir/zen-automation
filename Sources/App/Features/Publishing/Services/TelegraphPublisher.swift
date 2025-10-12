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
    private func convertTelegramFileIdToUrl(fileId: String) async throws -> String {
        logger.info("🔗 Конвертирую Telegram file_id в прямую ссылку: \(fileId)")
        
        // Получаем токен бота из переменных окружения
        guard let botToken = Environment.get("TELEGRAM_BOT_TOKEN") else {
            logger.error("❌ TELEGRAM_BOT_TOKEN не найден в переменных окружения")
            return fileId // Возвращаем как есть, если токен недоступен
        }
        
        let url = URI(string: "https://api.telegram.org/bot\(botToken)/getFile")
        
        let requestBody: [String: Any] = [
            "file_id": fileId
        ]
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        request.body = .init(data: try JSONSerialization.data(withJSONObject: requestBody))
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            logger.error("❌ Telegram getFile API error: \(response.status)")
            return fileId
        }
        
        struct GetFileResponse: Codable {
            let ok: Bool
            let result: FileInfo
            
            struct FileInfo: Codable {
                let file_id: String
                let file_unique_id: String
                let file_size: Int?
                let file_path: String
            }
        }
        
        let fileResponse = try response.content.decode(GetFileResponse.self)
        
        guard fileResponse.ok else {
            logger.error("❌ Telegram getFile returned ok=false")
            return fileId
        }
        
        let directUrl = "https://api.telegram.org/file/bot\(botToken)/\(fileResponse.result.file_path)"
        logger.info("✅ Получена прямая ссылка: \(directUrl)")
        
        return directUrl
    }
    
    /// Создаёт страницу в Telegraph и возвращает URL
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String {
        logger.info("📝 Создание страницы в Telegraph: \(title)")
        
        // Получаем или создаём access_token
        let token = try await getAccessToken()
        
        // Конвертируем Markdown в HTML-массив для Telegraph
        let htmlArray = try await convertToTelegraphHTMLArray(content: content, images: images)
        
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
    private func convertToTelegraphHTMLArray(content: String, images: [ZenImageModel]) async throws -> [[String: Any]] {
        var htmlArray: [[String: Any]] = []
        
        // 1. СНАЧАЛА добавляем главное изображение
        if let mainImage = images.first(where: { $0.position == 0 }) {
            // Конвертируем Telegram file_id в прямую ссылку
            let imageUrl = try await convertTelegramFileIdToUrl(fileId: mainImage.url)
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
        
        // 2. Обрабатываем контент - разбиваем на абзацы
        let paragraphs = content.components(separatedBy: "\n\n")
        var listItems: [Any] = [] // Массив для хранения структурированных элементов списка
        
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedParagraph.isEmpty {
                continue
            }
            
            // Проверяем, является ли это списком (начинается с эмодзи)
            if trimmedParagraph.hasPrefix("⚡️ ") || trimmedParagraph.hasPrefix("🎯 ") || 
               trimmedParagraph.hasPrefix("✈️ ") || trimmedParagraph.hasPrefix("💰 ") || 
               trimmedParagraph.hasPrefix("📍 ") {
                
                // Добавляем в список
                let listItemText = trimmedParagraph
                    .replacingOccurrences(of: "⚡️ ", with: "")
                    .replacingOccurrences(of: "🎯 ", with: "")
                    .replacingOccurrences(of: "✈️ ", with: "")
                    .replacingOccurrences(of: "💰 ", with: "")
                    .replacingOccurrences(of: "📍 ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Обрабатываем жирный текст в элементах списка
                let processedListItem = processTextWithBoldAndLinks(listItemText)
                listItems.append(processedListItem)
            } else {
                // Если есть накопленные элементы списка, создаём список
                if !listItems.isEmpty {
                    let listChildren = listItems.map { item in
                        [
                            "tag": "li",
                            "children": item
                        ]
                    }
                    
                    htmlArray.append([
                        "tag": "ul",
                        "children": listChildren
                    ])
                    listItems.removeAll()
                }
                
                // Обычный абзац
                var processedParagraph = trimmedParagraph
                
                // Заменяем одинарные переносы строк на пробелы
                processedParagraph = processedParagraph.replacingOccurrences(of: "\n", with: " ")
                
                // Проверяем, есть ли готовые HTML теги <b>текст</b> (от AI)
                if processedParagraph.contains("<b>") && processedParagraph.contains("</b>") {
                    // Конвертируем <b> в ** для единообразной обработки
                    processedParagraph = processedParagraph
                        .replacingOccurrences(of: "<b>", with: "**")
                        .replacingOccurrences(of: "</b>", with: "**")
                }
                
                // Обрабатываем текст с жирным выделением и ссылками
                let paragraphChildren = processTextWithBoldAndLinks(processedParagraph)
                htmlArray.append([
                    "tag": "p",
                    "children": paragraphChildren
                ])
            }
        }
        
        // Если остались элементы списка в конце, создаём список
        if !listItems.isEmpty {
            let listChildren = listItems.map { item in
                [
                    "tag": "li",
                    "children": item
                ]
            }
            
            htmlArray.append([
                "tag": "ul",
                "children": listChildren
            ])
        }
        
        // 3.5. Добавляем ссылку на бота в конце
        htmlArray.append([
            "tag": "p",
            "children": [
                [
                    "tag": "a",
                    "attrs": [
                        "href": "https://t.me/gdeVacationBot"
                    ],
                    "children": ["🤖 @gdeVacationBot - поиск дешёвых билетов"]
                ]
            ]
        ])
        
        // 4. Добавляем остальные изображения в конце (если есть)
        let additionalImages = images.filter { $0.position != 0 }
        for (index, image) in additionalImages.enumerated() {
            let imageUrl = try await convertTelegramFileIdToUrl(fileId: image.url)
            htmlArray.append([
                "tag": "figure",
                "children": [
                    [
                        "tag": "img",
                        "attrs": [
                            "src": imageUrl,
                            "alt": "Изображение \(index + 2)"
                        ]
                    ]
                ]
            ])
        }
        
        return htmlArray
    }
    
    /// Обрабатывает текст с жирным выделением и ссылками на бота
    func processTextWithBoldAndLinks(_ text: String) -> [Any] {
        var processedText = text
        
        // Сначала заменяем упоминания бота на ссылки
        processedText = processedText.replacingOccurrences(
            of: "@gdeVacationBot",
            with: "**@gdeVacationBot**"
        )
        
        // Проверяем, есть ли жирный текст или ссылки
        if processedText.contains("**") {
            return parseBoldText(processedText)
        } else {
            return [escapeHtml(processedText)]
        }
    }
    
    /// Парсит текст с жирным выделением **текст** в структурированный HTML для Telegraph
    func parseBoldText(_ text: String) -> [Any] {
        var children: [Any] = []
        let pattern = "\\*\\*([^*]+)\\*\\*"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // Если нет жирного текста, возвращаем весь текст с HTML-экранированием
        if matches.isEmpty {
            return [escapeHtml(text)]
        }
        
        var lastIndex = 0
        
        for match in matches {
            // Добавляем текст до жирного выделения
            if match.range.location > lastIndex {
                let beforeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let beforeText = (text as NSString).substring(with: beforeRange)
                if !beforeText.isEmpty {
                    children.append(escapeHtml(beforeText))
                }
            }
            
            // Добавляем жирный текст
            let boldText = (text as NSString).substring(with: match.range(at: 1))
            
            // Проверяем, является ли это упоминанием бота
            if boldText == "@gdeVacationBot" {
                children.append([
                    "tag": "a",
                    "attrs": [
                        "href": "https://t.me/gdeVacationBot"
                    ],
                    "children": ["@gdeVacationBot"]
                ])
            } else {
                children.append([
                    "tag": "b",
                    "children": [escapeHtml(boldText)]
                ])
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Добавляем оставшийся текст
        if lastIndex < text.utf16.count {
            let remainingText = (text as NSString).substring(from: lastIndex)
            if !remainingText.isEmpty {
                children.append(escapeHtml(remainingText))
            }
        }
        
        return children
    }
    
    /// Экранирует HTML символы для безопасного отображения
    func escapeHtml(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

/// Протокол для публикации в Telegraph
protocol TelegraphPublisherProtocol {
    func createPage(title: String, content: String, images: [ZenImageModel]) async throws -> String
}
