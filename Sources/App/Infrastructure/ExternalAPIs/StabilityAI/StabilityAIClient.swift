import Vapor
import Foundation

// Stability AI для генерации изображений
final class StabilityAIClient {
    private let client: Client
    private let apiKey: String
    private let uploadService: ImageUploadServiceProtocol
    private let baseURL = "https://api.stability.ai/v2beta"
    private let logger = Logger(label: "stability-client")
    
    init(client: Client, apiKey: String, uploadService: ImageUploadServiceProtocol) {
        self.client = client
        self.apiKey = apiKey
        self.uploadService = uploadService
    }
    
    func generateImage(prompt: String) async throws -> String {
        logger.info("🎨 Начинаю генерацию изображения через Stability AI")
        logger.info("📝 Prompt: \(prompt.prefix(200))...")
        
        let url = URI(string: "\(baseURL)/stable-image/generate/core")
        logger.info("🔗 URL: \(url)")
        
        // Создаём multipart/form-data запрос
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        request.headers.add(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
        
        // Формируем multipart body
        var body = ""
        
        // Добавляем prompt
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"prompt\"\r\n\r\n"
        body += "\(prompt)\r\n"
        
        // Добавляем output_format
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"output_format\"\r\n\r\n"
        body += "png\r\n"
        
        // Добавляем aspect_ratio
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"aspect_ratio\"\r\n\r\n"
        body += "16:9\r\n"
        
        // Закрываем multipart
        body += "--\(boundary)--\r\n"
        
        request.body = .init(string: body)
        
        logger.info("📤 Отправляю запрос к Stability AI...")
        let response = try await client.send(request)
        
        logger.info("📥 Получен ответ: status=\(response.status.code)")
        
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            logger.error("❌ Stability AI ошибка!")
            logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
            logger.error("   Body: \(errorBody)")
            throw Abort(.internalServerError, reason: "Stability AI error: \(response.status) - \(errorBody)")
        }
        
        // Stability AI возвращает binary изображение
        guard let imageData = response.body else {
            logger.error("❌ Нет данных изображения в ответе!")
            throw Abort(.internalServerError, reason: "No image data in Stability AI response")
        }
        
        let imageBytes = Data(buffer: imageData)
        
        logger.info("✅ Изображение успешно сгенерировано")
        logger.info("📦 Размер изображения: \(imageBytes.count) байт")
        
        // Загружаем на Telegraph и получаем публичный URL
        let publicURL = try await uploadService.uploadImage(data: imageBytes, format: .png)
        logger.info("✅ Изображение загружено на Telegraph: \(publicURL)")
        
        return publicURL
    }
}

