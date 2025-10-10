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
    private let logger: Logger
    
    init(client: Client, logger: Logger = Logger(label: "anthropic-client")) {
        self.client = client
        self.apiKey = AppConfig.anthropicKey
        self.model = AppConfig.anthropicModel
        self.logger = logger
    }
    
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        logger.info("🚀 Начинаю запрос к Claude API")
        
        // Логируем размер промптов
        let totalPromptSize = systemPrompt.count + userPrompt.count
        logger.info("📊 Размер промптов: system=\(systemPrompt.count), user=\(userPrompt.count), total=\(totalPromptSize)")
        
        // Проверяем, не слишком ли большой промпт
        if totalPromptSize > 150000 {
            logger.error("❌ Промпт слишком большой: \(totalPromptSize) символов")
            throw Abort(.badRequest, reason: "Промпт слишком большой: \(totalPromptSize) символов")
        }
        
        let url = URI(string: "\(baseURL)/messages")
        logger.info("🔗 URL: \(url)")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: "x-api-key", value: apiKey) // Полный ключ!
        request.headers.add(name: "anthropic-version", value: "2025-01-22")
        request.headers.add(name: .contentType, value: "application/json")
        
        logger.info("📋 Headers: x-api-key=\(String(apiKey.prefix(10)))..., anthropic-version=2025-01-22")
        logger.info("🤖 Model: \(model)")
        logger.info("⚙️ max_tokens: \(AppConfig.maxTokens), temperature: \(AppConfig.temperature)")
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": AppConfig.maxTokens,
            "temperature": AppConfig.temperature,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: requestBody)
            request.body = .init(data: data)
            
            logger.info("📤 Отправляю запрос к Claude API...")
            logger.info("📦 Размер тела запроса: \(data.count) байт")
            
            // Логируем первые 500 символов system prompt для отладки
            logger.info("📝 System prompt (первые 500 символов): \(systemPrompt.prefix(500))...")
            logger.info("📝 User prompt (первые 500 символов): \(userPrompt.prefix(500))...")
            
            let response = try await client.send(request)
            
            logger.info("📥 Получен ответ: status=\(response.status.code)")
            
            guard response.status == .ok else {
                // Детальное логирование ошибки
                let errorBody = response.body.map { String(buffer: $0) } ?? "No error body"
                logger.error("❌ Claude API ошибка!")
                logger.error("   Status: \(response.status.code) \(response.status.reasonPhrase)")
                logger.error("   Headers: \(response.headers)")
                logger.error("   Body: \(errorBody)")
                
                throw Abort(.internalServerError, reason: "Anthropic API error: \(response.status) - \(errorBody)")
            }
            
            struct AnthropicResponse: Codable {
                let content: [ContentBlock]
                let usage: Usage?
                
                struct ContentBlock: Codable {
                    let type: String
                    let text: String?
                }
                
                struct Usage: Codable {
                    let inputTokens: Int
                    let outputTokens: Int
                    
                    enum CodingKeys: String, CodingKey {
                        case inputTokens = "input_tokens"
                        case outputTokens = "output_tokens"
                    }
                }
            }
            
            let anthropicResponse = try response.content.decode(AnthropicResponse.self)
            
            // Логируем usage
            if let usage = anthropicResponse.usage {
                logger.info("📊 Tokens used: input=\(usage.inputTokens), output=\(usage.outputTokens)")
            }
            
            // Ищем первый text блок в ответе
            let textBlock = anthropicResponse.content.first { $0.type == "text" }
            
            guard let text = textBlock?.text else {
                logger.error("❌ Нет текстового блока в ответе!")
                logger.error("   Content blocks: \(anthropicResponse.content)")
                throw Abort(.internalServerError, reason: "No text content in Claude response")
            }
            
            logger.info("✅ Успешно получен текст: \(text.count) символов")
            logger.info("📝 Первые 300 символов ответа: \(text.prefix(300))...")
            
            return text
            
        } catch let error as Abort {
            logger.error("❌ Abort error: \(error.reason)")
            throw error
        } catch {
            logger.error("❌ Unexpected error: \(error)")
            logger.error("   Error type: \(type(of: error))")
            logger.error("   Error description: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "Claude API request failed: \(error.localizedDescription)")
        }
    }
    
    func generateImage(prompt: String) async throws -> String {
        // Anthropic не генерирует изображения, используем Stability AI
        let stabilityClient = StabilityAIClient(client: client, apiKey: AppConfig.stabilityAIKey)
        return try await stabilityClient.generateImage(prompt: prompt)
    }
}


