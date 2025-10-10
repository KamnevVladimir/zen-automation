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
    
    init(client: Client, apiKey: String, model: String = "claude-3-5-sonnet-20241022") {
        self.client = client
        self.apiKey = apiKey
        self.model = model
    }
    
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        let url = URI(string: "\(baseURL)/messages")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.headers.add(name: .contentType, value: "application/json")
        
        let requestBody = AnthropicChatRequest(
            model: model,
            messages: [
                .init(role: "user", content: userPrompt)
            ],
            maxTokens: AppConfig.openAIMaxTokens,
            temperature: AppConfig.openAITemperature,
            system: systemPrompt
        )
        
        try request.content.encode(requestBody)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            let error = try? response.content.decode(AnthropicError.self)
            throw Abort(.internalServerError, reason: error?.error.message ?? "Anthropic API error")
        }
        
        let anthropicResponse = try response.content.decode(AnthropicChatResponse.self)
        
        return anthropicResponse.content.first?.text ?? ""
    }
    
    func generateImage(prompt: String) async throws -> String {
        // Anthropic не поддерживает генерацию изображений
        // Используем Stability AI или возвращаем placeholder
        throw Abort(.notImplemented, reason: "Image generation not supported by Anthropic. Use Stability AI or OpenAI.")
    }
}

// MARK: - OpenAI Adapter (для обратной совместимости)

extension OpenAIClient: AIClientProtocol {
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        let messages: [OpenAIChatRequest.Message] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userPrompt)
        ]
        
        let response = try await chatCompletion(messages: messages, responseFormat: "json_object")
        return response.choices.first?.message.content ?? ""
    }
}

