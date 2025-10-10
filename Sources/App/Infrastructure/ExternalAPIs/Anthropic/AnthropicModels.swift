import Vapor

// MARK: - Claude API Models

struct AnthropicChatRequest: Content {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double
    let system: String?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case system
    }
    
    struct Message: Content {
        let role: String
        let content: String
    }
}

struct AnthropicChatResponse: Content {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let usage: Usage
    
    struct ContentBlock: Content {
        let type: String
        let text: String
    }
    
    struct Usage: Content {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

struct AnthropicError: Content, Error {
    let type: String
    let error: ErrorDetail
    
    struct ErrorDetail: Content {
        let type: String
        let message: String
    }
}

