import XCTest
@testable import App

final class StringExtensionTests: XCTestCase {
    
    func testSanitized() throws {
        let input = "  Hello World  \n"
        let expected = "Hello World"
        
        XCTAssertEqual(input.sanitized(), expected)
    }
    
    func testTruncateShortString() throws {
        let input = "Short"
        let truncated = input.truncate(to: 10)
        
        XCTAssertEqual(truncated, "Short")
    }
    
    func testTruncateLongString() throws {
        let input = "This is a very long string that needs to be truncated"
        let truncated = input.truncate(to: 10, addEllipsis: true)
        
        XCTAssertEqual(truncated, "This is a ...")
        XCTAssertEqual(truncated.count, 14)
    }
    
    func testTruncateWithoutEllipsis() throws {
        let input = "This is a very long string"
        let truncated = input.truncate(to: 10, addEllipsis: false)
        
        XCTAssertEqual(truncated, "This is a ")
        XCTAssertEqual(truncated.count, 10)
    }
    
    func testRemoveHTMLTags() throws {
        let input = "<p>Hello <strong>World</strong></p>"
        let expected = "Hello World"
        
        XCTAssertEqual(input.removeHTMLTags(), expected)
    }
    
    func testRemoveHTMLTagsComplex() throws {
        let input = """
        <div class="content">
            <h1>Title</h1>
            <p>Paragraph with <a href="link">link</a></p>
        </div>
        """
        let result = input.removeHTMLTags()
        
        XCTAssertFalse(result.contains("<"))
        XCTAssertFalse(result.contains(">"))
        XCTAssertTrue(result.contains("Title"))
        XCTAssertTrue(result.contains("Paragraph"))
    }
    
    func testRemoveHTMLTagsNoTags() throws {
        let input = "Plain text without tags"
        
        XCTAssertEqual(input.removeHTMLTags(), input)
    }
}

