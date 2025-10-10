import Vapor

// MARK: - Unified AI Client Protocol

protocol AIClientProtocol {
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String
    func generateImage(prompt: String) async throws -> String
}

// MARK: - Image Client Protocol

protocol ImageClientProtocol {
    func generateImage(prompt: String) async throws -> String
}
