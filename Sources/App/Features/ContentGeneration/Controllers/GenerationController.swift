import Vapor
import Fluent

struct GenerationController: RouteCollection {
    let contentGenerator: ContentGeneratorServiceProtocol
    let publisher: ZenPublisherProtocol
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "v1")
        
        api.post("generate", use: generate)
        api.post("generate", ":id", "publish", use: publish)
    }
    
    func generate(req: Request) async throws -> GenerationResponse {
        let request = try req.content.decode(GenerationRequest.self)
        
        req.logger.info("📝 Получен запрос на генерацию: \(request.templateType.rawValue)")
        
        let response = try await contentGenerator.generatePost(
            request: request,
            db: req.db
        )
        
        return response
    }
    
    func publish(req: Request) async throws -> PublishResult {
        guard let postId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid post ID")
        }
        
        guard let post = try await ZenPostModel.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "Post not found")
        }
        
        req.logger.info("📤 Публикация поста: \(post.title)")
        
        return try await publisher.publish(post: post, db: req.db)
    }
}

