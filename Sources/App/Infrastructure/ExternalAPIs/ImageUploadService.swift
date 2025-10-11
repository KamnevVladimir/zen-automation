import Vapor
import Foundation

/// Сервис для загрузки изображений на публичные хостинги
protocol ImageUploadServiceProtocol {
    func uploadImage(data: Data, format: ImageFormat) async throws -> String
}

enum ImageFormat: String {
    case png
    case jpeg
    
    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        }
    }
    
    var fileExtension: String {
        rawValue
    }
}

/// Загрузка на Telegraph (telegra.ph/upload)
/// Telegraph API бесплатен и не требует ключа
final class TelegraphImageUploadService: ImageUploadServiceProtocol {
    private let client: Client
    private let logger: Logger
    private let uploadURL = "https://telegra.ph/upload"
    
    init(client: Client, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    func uploadImage(data: Data, format: ImageFormat) async throws -> String {
        logger.info("📤 Загружаю изображение на Telegraph (\(data.count) байт)")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URI(string: uploadURL)
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
        
        // Формируем multipart/form-data body
        var body = Data()
        
        // Добавляем файл
        let fileName = "image.\(format.fileExtension)"
        let fieldName = "file"
        
        // Начало boundary
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(format.mimeType)\r\n\r\n".data(using: .utf8)!)
        
        // Данные файла
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Закрывающий boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.body = .init(data: body)
        
        logger.info("📤 Отправляю запрос на Telegraph...")
        let response = try await client.send(request)
        
        logger.info("📥 Получен ответ: status=\(response.status.code)")
        
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Telegraph upload error!")
            logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
            logger.error("   Body: \(errorBody)")
            throw Abort(.internalServerError, reason: "Telegraph upload failed: \(response.status)")
        }
        
        // Парсим ответ
        guard let responseBody = response.body else {
            logger.error("❌ Нет тела ответа от Telegraph!")
            throw Abort(.internalServerError, reason: "No response body from Telegraph")
        }
        
        // Telegraph возвращает: [{"src":"/file/abc123.png"}]
        let responseData = Data(buffer: responseBody)
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [[String: Any]],
              let firstItem = json.first,
              let src = firstItem["src"] as? String else {
            let bodyString = String(data: responseData, encoding: .utf8) ?? "Cannot decode"
            logger.error("❌ Не удалось распарсить ответ Telegraph: \(bodyString)")
            throw Abort(.internalServerError, reason: "Invalid Telegraph response format")
        }
        
        // Telegraph возвращает относительный путь, добавляем домен
        let fullURL = "https://telegra.ph\(src)"
        
        logger.info("✅ Изображение загружено: \(fullURL)")
        
        return fullURL
    }
}

