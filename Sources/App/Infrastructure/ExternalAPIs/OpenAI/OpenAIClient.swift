import Vapor

protocol OpenAIClientProtocol {
    func chatCompletion(messages: [OpenAIChatRequest.Message], responseFormat: String?) async throws -> OpenAIChatResponse
    func generateImage(prompt: String) async throws -> String
}

final class OpenAIClient: OpenAIClientProtocol {
    private let client: Client
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(client: Client, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    func chatCompletion(
        messages: [OpenAIChatRequest.Message],
        responseFormat: String? = nil
    ) async throws -> OpenAIChatResponse {
        let url = URI(string: "\(baseURL)/chat/completions")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        request.headers.add(name: .contentType, value: "application/json")
        
        let requestBody = OpenAIChatRequest(
            model: AppConfig.openAIModel,
            messages: messages,
            temperature: AppConfig.openAITemperature,
            maxTokens: AppConfig.openAIMaxTokens,
            responseFormat: responseFormat == "json_object" ? OpenAIChatRequest.ResponseFormat(type: "json_object") : nil
        )
        
        try request.content.encode(requestBody)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            let error = try? response.content.decode(OpenAIError.self)
            throw Abort(.internalServerError, reason: error?.error.message ?? "OpenAI API error")
        }
        
        return try response.content.decode(OpenAIChatResponse.self)
    }
    
    func generateImage(prompt: String) async throws -> String {
        let url = URI(string: "\(baseURL)/images/generations")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        request.headers.add(name: .contentType, value: "application/json")
        
        let requestBody = DallERequest(prompt: prompt)
        try request.content.encode(requestBody)
        
        let response = try await client.send(request)
        
        guard response.status == .ok else {
            let error = try? response.content.decode(OpenAIError.self)
            throw Abort(.internalServerError, reason: error?.error.message ?? "DALL-E API error")
        }
        
        let dalleResponse = try response.content.decode(DallEResponse.self)
        
        guard let imageURL = dalleResponse.data.first?.url else {
            throw Abort(.internalServerError, reason: "No image URL in response")
        }
        
        return imageURL
    }
}

