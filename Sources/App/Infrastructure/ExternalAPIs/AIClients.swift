import Vapor

// MARK: - Image Client Protocol (only for future use)

protocol ImageClientProtocol {
    func generateImage(prompt: String) async throws -> String
}
