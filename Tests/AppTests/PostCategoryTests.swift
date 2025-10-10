import XCTest
@testable import App

final class PostCategoryTests: XCTestCase {
    
    func testAllCategoriesHaveRawValues() throws {
        let categories: [PostCategory] = [
            .destination, .lifehack, .comparison, .budget,
            .trending, .season, .weekend, .mistake,
            .hiddenGem, .visaFree
        ]
        
        for category in categories {
            XCTAssertFalse(category.rawValue.isEmpty)
            XCTAssertFalse(category.rawValue.contains(" "))
        }
    }
    
    func testCategoryEncoding() throws {
        let category = PostCategory.destination
        let encoder = JSONEncoder()
        let data = try encoder.encode(category)
        
        XCTAssertNotNil(data)
        
        let decoded = try JSONDecoder().decode(PostCategory.self, from: data)
        XCTAssertEqual(decoded, category)
    }
    
    func testAllCategoriesAreCodable() throws {
        let categories: [PostCategory] = [
            .destination, .lifehack, .comparison, .budget,
            .trending, .season, .weekend, .mistake,
            .hiddenGem, .visaFree
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for category in categories {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(PostCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}

final class PostStatusTests: XCTestCase {
    
    func testAllStatusesHaveRawValues() throws {
        let statuses: [PostStatus] = [.draft, .published, .failed, .pending]
        
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty)
        }
    }
    
    func testStatusEncoding() throws {
        let status = PostStatus.published
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        XCTAssertNotNil(data)
        
        let decoded = try JSONDecoder().decode(PostStatus.self, from: data)
        XCTAssertEqual(decoded, status)
    }
}

