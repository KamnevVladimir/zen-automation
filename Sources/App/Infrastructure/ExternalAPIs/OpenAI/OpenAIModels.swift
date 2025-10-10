import Vapor

// MARK: - Chat Completion Models

struct OpenAIChatRequest: Content {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
    
    struct Message: Content {
        let role: String
        let content: String
    }
    
    struct ResponseFormat: Content {
        let type: String
    }
}

struct OpenAIChatResponse: Content {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Content {
        let index: Int
        let message: Message
        let finishReason: String
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
        
        struct Message: Content {
            let role: String
            let content: String
        }
    }
    
    struct Usage: Content {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - DALL-E Models

struct DallERequest: Content {
    let model: String
    let prompt: String
    let n: Int
    let size: String
    let quality: String
    let responseFormat: String
    
    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case n
        case size
        case quality
        case responseFormat = "response_format"
    }
    
    init(
        model: String = AppConfig.dalleModel,
        prompt: String,
        n: Int = 1,
        size: String = AppConfig.dalleSize,
        quality: String = AppConfig.dalleQuality
    ) {
        self.model = model
        self.prompt = prompt
        self.n = n
        self.size = size
        self.quality = quality
        self.responseFormat = "url"
    }
}

struct DallEResponse: Content {
    let created: Int
    let data: [ImageData]
    
    struct ImageData: Content {
        let url: String?
        let revisedPrompt: String?
        
        enum CodingKeys: String, CodingKey {
            case url
            case revisedPrompt = "revised_prompt"
        }
    }
}

// MARK: - Error Models

struct OpenAIError: Content, Error {
    let error: ErrorDetail
    
    struct ErrorDetail: Content {
        let message: String
        let type: String
        let code: String?
    }
}

