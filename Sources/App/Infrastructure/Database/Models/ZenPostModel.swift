import Vapor
import Fluent

final class ZenPostModel: Model, Content {
    static let schema = "zen_posts"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @OptionalField(key: "subtitle")
    var subtitle: String?
    
    @Field(key: "body")
    var body: String
    
    @OptionalField(key: "short_post")
    var shortPost: String?
    
    @OptionalField(key: "full_post")
    var fullPost: String?
    
    @Field(key: "tags")
    var tags: [String]
    
    @OptionalField(key: "meta_description")
    var metaDescription: String?
    
    @Field(key: "template_type")
    var templateType: String
    
    @Enum(key: "status")
    var status: PostStatus
    
    @OptionalField(key: "published_at")
    var publishedAt: Date?
    
    @OptionalField(key: "zen_article_id")
    var zenArticleId: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Children(for: \.$post)
    var images: [ZenImageModel]
    
    @Children(for: \.$post)
    var metrics: [ZenMetricModel]
    
    init() {}
    
    init(
        id: UUID? = nil,
        title: String,
        subtitle: String? = nil,
        body: String,
        shortPost: String? = nil,
        fullPost: String? = nil,
        tags: [String] = [],
        metaDescription: String? = nil,
        templateType: String,
        status: PostStatus = .draft
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.shortPost = shortPost
        self.fullPost = fullPost
        self.tags = tags
        self.metaDescription = metaDescription
        self.templateType = templateType
        self.status = status
    }
}

