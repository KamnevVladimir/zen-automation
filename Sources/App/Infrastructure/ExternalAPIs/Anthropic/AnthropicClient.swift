import Vapor

protocol AIClientProtocol {
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String
    func generateImage(prompt: String) async throws -> String
}

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
        // Логируем размер промптов
        let totalPromptSize = systemPrompt.count + userPrompt.count
        print("📊 Размер промптов: system=\(systemPrompt.count), user=\(userPrompt.count), total=\(totalPromptSize)")
        
        // Проверяем, не слишком ли большой промпт (Claude 4.5 поддерживает до 200K токенов)
        if totalPromptSize > 150000 {
            throw Abort(.badRequest, reason: "Промпт слишком большой: \(totalPromptSize) символов")
        }
        
        let url = URI(string: "\(baseURL)/messages")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2025-01-22")
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
            // Читаем тело ответа для детальной ошибки
            let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
            throw Abort(.internalServerError, reason: "Anthropic API error: \(response.status) - \(errorBody)")
        }
        
        struct AnthropicResponse: Codable {
            let content: [ContentBlock]
            
            struct ContentBlock: Codable {
                let type: String
                let text: String?
            }
        }
        
        let anthropicResponse = try response.content.decode(AnthropicResponse.self)
        
        // Ищем первый text блок в ответе
        let textBlock = anthropicResponse.content.first { $0.type == "text" }
        return textBlock?.text ?? ""
    }
    
    func generateImage(prompt: String) async throws -> String {
        // Anthropic не генерирует изображения, используем Stability AI
        let stabilityClient = StabilityAIClient(client: client, apiKey: AppConfig.stabilityAIKey)
        return try await stabilityClient.generateImage(prompt: prompt)
    }
}


