import XCTest
@testable import App

final class OpenAIClientTests: XCTestCase {
    
    func testOpenAIChatRequestEncoding() throws {
        let request = OpenAIChatRequest(
            model: "gpt-4-turbo-preview",
            messages: [
                .init(role: "system", content: "You are a helpful assistant"),
                .init(role: "user", content: "Hello")
            ],
            temperature: 0.7,
            maxTokens: 4000,
            responseFormat: nil
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testDallERequestEncoding() throws {
        let request = DallERequest(
            model: "dall-e-3",
            prompt: "A beautiful sunset over the ocean",
            n: 1,
            size: "1792x1024",
            quality: "hd"
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        
        XCTAssertNotNil(data)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "dall-e-3")
        XCTAssertEqual(json?["n"] as? Int, 1)
        XCTAssertEqual(json?["quality"] as? String, "hd")
    }
    
    func testOpenAIChatResponseDecoding() throws {
        let jsonString = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4-turbo-preview",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Test response"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(OpenAIChatResponse.self, from: data)
        
        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.model, "gpt-4-turbo-preview")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].message.content, "Test response")
        XCTAssertEqual(response.usage.totalTokens, 30)
    }
    
    func testDallEResponseDecoding() throws {
        let jsonString = """
        {
            "created": 1677652288,
            "data": [{
                "url": "https://example.com/image.png",
                "revised_prompt": "A beautiful sunset..."
            }]
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(DallEResponse.self, from: data)
        
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].url, "https://example.com/image.png")
        XCTAssertNotNil(response.data[0].revisedPrompt)
    }
}

