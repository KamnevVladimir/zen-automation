import Vapor

// Stability AI для генерации изображений (альтернатива DALL-E)
final class StabilityAIClient {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.stability.ai/v2beta"
    
    init(client: Client, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    func generateImage(prompt: String) async throws -> String {
        let url = URI(string: "\(baseURL)/stable-image/generate/core")
        
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
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Stability AI error: \(response.status)")
        }
        
        struct StabilityResponse: Content {
            let image: String // base64 encoded image
        }
        
        let stabilityResponse = try response.content.decode(StabilityResponse.self)
        let base64Image = stabilityResponse.image
        
        // Здесь нужно загрузить base64 на CDN и вернуть URL
        // Пока возвращаем data URL
        return "data:image/png;base64,\(base64Image)"
    }
}

