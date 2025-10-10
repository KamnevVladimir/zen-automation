import XCTest
import XCTVapor
@testable import App

final class AppTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try configure(app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testHealthEndpoint() async throws {
        try app.test(.GET, "health") { res in
            XCTAssertEqual(res.status, .ok)
        }
    }
    
    func testRootEndpoint() async throws {
        try app.test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode([String: String].self)
            XCTAssertEqual(response["service"], "zen-automation")
            XCTAssertEqual(response["status"], "running")
        }
    }
    
    func testPostsEndpoint() async throws {
        try app.test(.GET, "/api/v1/posts") { res in
            XCTAssertEqual(res.status, .ok)
            
            let posts = try res.content.decode([ZenPostModel].self)
            XCTAssertNotNil(posts)
        }
    }
    
    func testMetricsEndpoint() async throws {
        try app.test(.GET, "/api/v1/metrics") { res in
            XCTAssertEqual(res.status, .ok)
            
            let metrics = try res.content.decode([String: Double].self)
            XCTAssertNotNil(metrics["total_posts"])
            XCTAssertNotNil(metrics["published_posts"])
            XCTAssertNotNil(metrics["success_rate"])
        }
    }
}

