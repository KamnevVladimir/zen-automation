import Vapor
import Foundation

/// Загрузка изображений через Telegram Bot API (альтернатива Telegraph)
/// Загружаем в admin чат, получаем file_id, используем для отправки в канал
final class TelegramImageUploader: ImageUploadServiceProtocol {
    private let client: Client
    private let logger: Logger
    private let botToken: String
    private let adminChatId: String
    
    init(client: Client, logger: Logger, botToken: String, adminChatId: String) {
        self.client = client
        self.logger = logger
        self.botToken = botToken
        self.adminChatId = adminChatId
    }
    
    func uploadImage(data: Data, format: ImageFormat) async throws -> String {
        logger.info("📤 Загружаю изображение через Telegram Bot API (\(data.count) байт)")
        
        // Telegram Bot API имеет лимит 20 МБ для фото, 50 МБ для файлов
        if data.count > 20 * 1024 * 1024 {
            logger.warning("⚠️ Изображение слишком большое для Telegram: \(data.count) байт")
            throw Abort(.badRequest, reason: "Image too large for Telegram (max 20MB)")
        }
        
        let boundary = "----WebKitFormBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let url = URI(string: "https://api.telegram.org/bot\(botToken)/sendPhoto")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
        
        // Формируем multipart/form-data body
        var body = Data()
        
        // Добавляем chat_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(adminChatId)\r\n".data(using: .utf8)!)
        
        // Добавляем файл
        let fileName = "image.\(format.fileExtension)"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(format.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Закрывающий boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.body = .init(data: body)
        
        logger.info("📤 Отправляю запрос к Telegram Bot API...")
        let response = try await client.send(request)
        
        logger.info("📥 Получен ответ: status=\(response.status.code)")
        
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Telegram Bot API upload error!")
            logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
            logger.error("   Body: \(errorBody)")
            throw Abort(.internalServerError, reason: "Telegram Bot API upload failed: \(response.status)")
        }
        
        // Парсим ответ от Telegram
        guard let responseBody = response.body else {
            logger.error("❌ Нет тела ответа от Telegram!")
            throw Abort(.internalServerError, reason: "No response body from Telegram")
        }
        
        struct TelegramResponse: Codable {
            let ok: Bool
            let result: Result?
            
            struct Result: Codable {
                let photo: [PhotoSize]
                
                struct PhotoSize: Codable {
                    let fileId: String
                    let fileUniqueId: String
                    let width: Int
                    let height: Int
                    let fileSize: Int?
                    
                    enum CodingKeys: String, CodingKey {
                        case fileId = "file_id"
                        case fileUniqueId = "file_unique_id"
                        case width, height
                        case fileSize = "file_size"
                    }
                }
            }
        }
        
        let responseData = Data(buffer: responseBody)
        
        guard let telegramResponse = try? JSONDecoder().decode(TelegramResponse.self, from: responseData),
              telegramResponse.ok,
              let result = telegramResponse.result,
              let largestPhoto = result.photo.max(by: { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }) else {
            let bodyString = String(data: responseData, encoding: .utf8) ?? "Cannot decode"
            logger.error("❌ Не удалось распарсить ответ Telegram: \(bodyString)")
            throw Abort(.internalServerError, reason: "Invalid Telegram response format")
        }
        
        // Возвращаем file_id - его можно использовать для отправки в канал
        let fileId = largestPhoto.fileId
        
        logger.info("✅ Изображение загружено в Telegram, file_id: \(fileId)")
        
        return fileId
    }
}

