import Vapor

// Stability AI для генерации изображений
final class StabilityAIClient {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.stability.ai/v2beta"
    private let logger = Logger(label: "stability-client")
    
    init(client: Client, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    func generateImage(prompt: String) async throws -> String {
        logger.info("🎨 Начинаю генерацию изображения через Stability AI")
        logger.info("📝 Prompt: \(prompt.prefix(200))...")
        
        let url = URI(string: "\(baseURL)/stable-image/generate/core")
        logger.info("🔗 URL: \(url)")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "output_format": "png",
            "aspect_ratio": "16:9"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
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
        
        struct StabilityResponse: Content {
            let image: String // base64 encoded image
        }
        
        let stabilityResponse = try response.content.decode(StabilityResponse.self)
        let base64Image = stabilityResponse.image
        
        logger.info("✅ Изображение успешно сгенерировано")
        logger.info("📦 Размер base64: \(base64Image.count) символов")
        
        // Здесь нужно загрузить base64 на CDN и вернуть URL
        // Пока возвращаем data URL
        return "data:image/png;base64,\(base64Image)"
    }
}

