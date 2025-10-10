import Vapor
import Fluent

final class ZenImageModel: Model, Content {
    static let schema = "zen_images"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: ZenPostModel
    
    @Field(key: "url")
    var url: String
    
    @Field(key: "prompt")
    var prompt: String
    
    @OptionalField(key: "dalle_id")
    var dalleId: String?
    
    @Field(key: "position")
    var position: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        postId: UUID,
        url: String,
        prompt: String,
        dalleId: String? = nil,
        position: Int = 0
    ) {
        self.id = id
        self.$post.id = postId
        self.url = url
        self.prompt = prompt
        self.dalleId = dalleId
        self.position = position
    }
}

