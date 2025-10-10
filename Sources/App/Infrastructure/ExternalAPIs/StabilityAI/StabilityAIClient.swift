import Vapor

// Stability AI для генерации изображений (альтернатива DALL-E)
final class StabilityAIClient {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.stability.ai/v1"
    
    init(client: Client, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    func generateImage(prompt: String) async throws -> String {
        let url = URI(string: "\(baseURL)/generation/stable-diffusion-xl-1024-v1-0/text-to-image")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "text_prompts": [
                ["text": prompt, "weight": 1]
            ],
            "cfg_scale": 7,
            "height": 1024,
            "width": 1792,
            "samples": 1,
            "steps": 30
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Stability AI error: \(response.status)")
        }
        
        struct StabilityResponse: Content {
            let artifacts: [Artifact]
            
            struct Artifact: Content {
                let base64: String
                let finishReason: String
                
                enum CodingKeys: String, CodingKey {
                    case base64
                    case finishReason = "finishReason"
                }
            }
        }
        
        let stabilityResponse = try response.content.decode(StabilityResponse.self)
        
        guard let base64Image = stabilityResponse.artifacts.first?.base64 else {
            throw Abort(.internalServerError, reason: "No image in response")
        }
        
        // Здесь нужно загрузить base64 на CDN и вернуть URL
        // Пока возвращаем data URL
        return "data:image/png;base64,\(base64Image)"
    }
}

