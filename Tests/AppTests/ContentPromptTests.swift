import XCTest
@testable import App

final class ContentPromptTests: XCTestCase {
    
    func testSystemPromptNotEmpty() throws {
        let prompt = ContentPrompt.buildSystemPrompt()
        
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("эксперт"))
        XCTAssertTrue(prompt.contains("ПРАВИЛА"))
        XCTAssertTrue(prompt.contains("JSON"))
    }
    
    func testDestinationPrompt() throws {
        let request = GenerationRequest(
            templateType: .destination,
            topic: "Таиланд",
            destinations: ["Бангкок", "Пхукет"],
            priceData: [
                .init(destination: "Бангкок", price: 28500, currency: "RUB", date: "2024-12-01")
            ],
            trendData: nil
        )
        
        let prompt = ContentPrompt.buildUserPrompt(for: request)
        
        XCTAssertTrue(prompt.contains("Destination Post"))
        XCTAssertTrue(prompt.contains("28500"))
        XCTAssertTrue(prompt.contains("gdeVacationBot"))
    }
    
    func testLifehackPrompt() throws {
        let request = GenerationRequest(
            templateType: .lifehack,
            topic: nil,
            destinations: nil,
            priceData: nil,
            trendData: nil
        )
        
        let prompt = ContentPrompt.buildUserPrompt(for: request)
        
        XCTAssertTrue(prompt.contains("Lifehack"))
        XCTAssertTrue(prompt.contains("секреты"))
        XCTAssertTrue(prompt.contains("лайфхак"))
    }
    
    func testComparisonPrompt() throws {
        let request = GenerationRequest(
            templateType: .comparison,
            topic: nil,
            destinations: ["Турция", "Египет"],
            priceData: nil,
            trendData: nil
        )
        
        let prompt = ContentPrompt.buildUserPrompt(for: request)
        
        XCTAssertTrue(prompt.contains("Comparison"))
        XCTAssertTrue(prompt.contains("Турция"))
        XCTAssertTrue(prompt.contains("Египет"))
    }
    
    func testBudgetPrompt() throws {
        let request = GenerationRequest(
            templateType: .budget,
            topic: nil,
            destinations: nil,
            priceData: nil,
            trendData: nil
        )
        
        let prompt = ContentPrompt.buildUserPrompt(for: request)
        
        XCTAssertTrue(prompt.contains("Budget"))
        XCTAssertTrue(prompt.contains("50,000"))
    }
    
    func testTrendingPrompt() throws {
        let request = GenerationRequest(
            templateType: .trending,
            topic: nil,
            destinations: nil,
            priceData: nil,
            trendData: .init(popularDestinations: ["Турция", "ОАЭ"], searchVolume: 1000)
        )
        
        let prompt = ContentPrompt.buildUserPrompt(for: request)
        
        XCTAssertTrue(prompt.contains("Trending"))
        XCTAssertTrue(prompt.contains("Турция"))
        XCTAssertTrue(prompt.contains("ОАЭ"))
    }
    
    func testImagePromptGeneration() throws {
        let title = "Куда полететь на выходные"
        
        let mainPrompt = ContentPrompt.buildImagePrompt(for: title, position: 0)
        let supportPrompt = ContentPrompt.buildImagePrompt(for: title, position: 1)
        
        XCTAssertTrue(mainPrompt.contains("Hero image"))
        XCTAssertTrue(mainPrompt.contains(title))
        XCTAssertTrue(mainPrompt.contains("16:9"))
        
        XCTAssertTrue(supportPrompt.contains("Supporting image"))
        XCTAssertTrue(supportPrompt.contains(title))
    }
    
    func testAllPromptTypesHaveBotMention() throws {
        let categories: [PostCategory] = [
            .destination, .lifehack, .comparison,
            .budget, .trending, .season,
            .weekend, .mistake, .hiddenGem
        ]
        
        for category in categories {
            let request = GenerationRequest(
                templateType: category,
                topic: "test",
                destinations: ["Test1", "Test2"],
                priceData: nil,
                trendData: nil
            )
            
            let prompt = ContentPrompt.buildUserPrompt(for: request)
            XCTAssertTrue(
                prompt.contains("gdeVacationBot"),
                "Промпт для \(category.rawValue) должен содержать упоминание бота"
            )
        }
    }
}

