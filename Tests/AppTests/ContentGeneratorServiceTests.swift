import XCTest
import Vapor
@testable import App

final class ContentGeneratorServiceTests: XCTestCase {
    
    /// Тест: парсинг JSON с пустым body и заполненным fullPost
    func testJSONParsingWithEmptyBodyAndFullPost() throws {
        let json = """
        {
            "title": "Тестовый заголовок",
            "subtitle": "Подзаголовок",
            "body": "",
            "short_post": "Короткий пост для Telegram",
            "full_post": "\(String(repeating: "Полный текст статьи. ", count: 200))## Подзаголовок\\nСсылка на @gdeVacationBot\\n",
            "tags": ["путешествия", "туризм"],
            "meta_description": "Описание",
            "image_prompts_english": ["Travel photo"],
            "estimated_read_time": 5
        }
        """
        
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        let body = parsed["body"] as? String ?? ""
        let fullPost = parsed["full_post"] as? String ?? body
        
        // body должен быть пустым
        XCTAssertTrue(body.isEmpty, "body должен быть пустым")
        
        // fullPost должен быть заполнен
        XCTAssertFalse(fullPost.isEmpty, "fullPost должен быть заполнен")
        XCTAssertGreaterThan(fullPost.count, 3000, "fullPost должен содержать достаточно текста")
    }
    
    /// Тест: валидация должна падать для пустого body
    func testValidatorFailsForEmptyBody() {
        let validator = ContentValidator()
        let emptyBody = ""
        let tags = ["путешествия"]
        
        let result = validator.validate(body: emptyBody, tags: tags)
        
        XCTAssertFalse(result.isValid, "Пустой body не должен проходить валидацию")
        XCTAssertTrue(result.issues.contains { $0.contains("короткий") })
    }
    
    /// Тест: валидация должна проходить для полного fullPost
    func testValidatorPassesForFullPost() {
        let validator = ContentValidator()
        let fullPost = String(repeating: "Качественный текст статьи про путешествия. ", count: 100) +
                       "## Первый подзаголовок\n" +
                       "Много полезной информации.\n" +
                       "## Второй подзаголовок\n" +
                       "Используйте бота @gdeVacationBot для поиска дешевых билетов.\n" +
                       "Еще больше текста для длины."
        let tags = ["путешествия", "туризм", "лайфхаки"]
        
        let result = validator.validate(body: fullPost, tags: tags)
        
        XCTAssertTrue(result.isValid, "Полный fullPost должен проходить валидацию")
        XCTAssertGreaterThanOrEqual(result.score, 0.7)
    }
}

// MARK: - Mock AI Client

final class MockAIClient: AIClientProtocol {
    let textResponse: String
    let imageURL: String
    
    init(textResponse: String, imageURL: String) {
        self.textResponse = textResponse
        self.imageURL = imageURL
    }
    
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        return textResponse
    }
    
    func generateImage(prompt: String) async throws -> String {
        return imageURL
    }
}

