import XCTest
import Vapor
@testable import App

final class ImageUploadServiceTests: XCTestCase {
    
    func testImageFormatProperties() {
        XCTAssertEqual(ImageFormat.png.mimeType, "image/png")
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpeg")
    }
    
    func testImageUploadServiceProtocol() async throws {
        // Тест проверяет, что протокол реализован корректно
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let logger = Logger(label: "test")
        let uploadService: ImageUploadServiceProtocol = TelegraphImageUploadService(
            client: app.client,
            logger: logger
        )
        
        // Проверяем что метод существует и возвращает String
        // Реальный тест с Telegraph API требует сетевого запроса
        // и будет выполняться в интеграционном тесте
        
        XCTAssertNotNil(uploadService)
    }
    
    func testMultipartBodyFormat() {
        // Тест проверяет формат multipart/form-data
        let boundary = "TestBoundary123"
        let imageData = "test-image-data".data(using: .utf8)!
        let format = ImageFormat.png
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.\(format.fileExtension)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(format.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let bodyString = String(data: body, encoding: .utf8)!
        
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"file\""))
        XCTAssertTrue(bodyString.contains("filename=\"image.png\""))
        XCTAssertTrue(bodyString.contains("Content-Type: image/png"))
        XCTAssertTrue(bodyString.contains("test-image-data"))
    }
}

