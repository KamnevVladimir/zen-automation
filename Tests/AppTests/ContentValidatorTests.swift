import XCTest
@testable import App

final class ContentValidatorTests: XCTestCase {
    var validator: ContentValidator!
    
    override func setUp() {
        super.setUp()
        validator = ContentValidator(
            minLength: 3000,
            maxLength: 7000,
            botUsername: "gdeVacationBot"
        )
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
    
    func testValidContent() throws {
        let body = String(repeating: "Отличная статья про путешествия. ", count: 100) +
                   "## Подзаголовок\n" +
                   "Больше информации в @gdeVacationBot"
        let tags = ["путешествия", "дзен", "туризм"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertTrue(result.isValid, "Валидный контент должен проходить проверку")
        XCTAssertGreaterThanOrEqual(result.score, 0.7, "Score должен быть >= 0.7")
        XCTAssertTrue(result.issues.isEmpty, "Не должно быть ошибок")
    }
    
    func testTooShortContent() throws {
        let body = "Короткий текст"
        let tags = ["тест"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertFalse(result.isValid, "Короткий текст не должен проходить валидацию")
        XCTAssertTrue(result.issues.contains { $0.contains("короткий") })
    }
    
    func testMissingBotMention() throws {
        let body = String(repeating: "Текст без упоминания бота. ", count: 200) +
                   "## Подзаголовок\n"
        let tags = ["путешествия"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertFalse(result.isValid, "Контент без упоминания бота не должен проходить")
        XCTAssertTrue(result.issues.contains { $0.contains("бота") })
    }
    
    func testTooManyBotMentions() throws {
        let body = String(repeating: "Проверьте @gdeVacationBot сейчас! ", count: 200) +
                   "## Подзаголовок\n"
        let tags = ["путешествия"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertTrue(result.issues.contains { $0.contains("много упоминаний") })
    }
    
    func testBannedWords() throws {
        let body = String(repeating: "Отличная статья. ", count: 200) +
                   "## Подзаголовок\n" +
                   "Гарантия 100% успеха! @gdeVacationBot"
        let tags = ["путешествия"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("запрещённое слово") })
    }
    
    func testMissingHeaders() throws {
        let body = String(repeating: "Текст без подзаголовков. ", count: 200) +
                   "@gdeVacationBot"
        let tags = ["путешествия"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertTrue(result.issues.contains { $0.contains("подзаголовки") })
    }
    
    func testEmptyTags() throws {
        let body = String(repeating: "Хороший текст. ", count: 200) +
                   "## Подзаголовок\n" +
                   "@gdeVacationBot"
        let tags: [String] = []
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertTrue(result.issues.contains { $0.contains("тегов") })
    }
    
    func testPlaceholders() throws {
        let body = String(repeating: "Текст. ", count: 200) +
                   "## TODO: Добавить информацию\n" +
                   "@gdeVacationBot"
        let tags = ["тест"]
        
        let result = validator.validate(body: body, tags: tags)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("заполнители") })
    }
    
    func testScoreCalculation() throws {
        // Идеальный контент
        let perfectBody = String(repeating: "Качественная статья. ", count: 200) +
                         "## Подзаголовок 1\n" +
                         "Информация про @gdeVacationBot\n" +
                         "## Подзаголовок 2\n" +
                         "Ещё больше полезного контента."
        let perfectTags = ["путешествия", "туризм", "бюджет"]
        
        let result = validator.validate(body: perfectBody, tags: perfectTags)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.score, 1.0, accuracy: 0.1)
    }
}

