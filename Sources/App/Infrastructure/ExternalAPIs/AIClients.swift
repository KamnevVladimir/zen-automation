import Vapor

// MARK: - Unified AI Client Protocol

protocol AIClientProtocol {
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String
    func generateImage(prompt: String) async throws -> String
}

// MARK: - Anthropic Claude Client

final class AnthropicClient: AIClientProtocol {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let model: String
    
    init(client: Client) {
        self.client = client
        self.apiKey = AppConfig.anthropicKey
        self.model = AppConfig.anthropicModel
    }
    
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        let url = URI(string: "\(baseURL)/messages")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.headers.add(name: .contentType, value: "application/json")
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": AppConfig.maxTokens,
            "temperature": AppConfig.temperature,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: requestBody)
        request.body = .init(data: data)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Anthropic API error: \(response.status)")
        }
        
        struct AnthropicResponse: Codable {
            let content: [ContentBlock]
            
            struct ContentBlock: Codable {
                let text: String
            }
        }
        
        let anthropicResponse = try response.content.decode(AnthropicResponse.self)
        return anthropicResponse.content.first?.text ?? ""
    }
    
    func generateImage(prompt: String) async throws -> String {
        // Anthropic не генерирует изображения, используем Stability AI
        let stabilityClient = StabilityAIClient(client: client)
        return try await stabilityClient.generateImage(prompt: prompt)
    }
}

// MARK: - Stability AI Client

final class StabilityAIClient {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.stability.ai/v1"
    
    init(client: Client) {
        self.client = client
        self.apiKey = AppConfig.stabilityAIKey
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
        
        // Возвращаем data URL (в продакшене нужно загружать на CDN)
        return "data:image/png;base64,\(base64Image)"
    }
}
