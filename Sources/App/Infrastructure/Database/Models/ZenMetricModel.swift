import Vapor
import Fluent

final class ZenMetricModel: Model, Content {
    static let schema = "zen_metrics"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: ZenPostModel
    
    @Field(key: "views")
    var views: Int
    
    @Field(key: "reads")
    var reads: Int
    
    @Field(key: "read_percentage")
    var readPercentage: Double
    
    @Field(key: "likes")
    var likes: Int
    
    @Field(key: "comments")
    var comments: Int
    
    @Field(key: "shares")
    var shares: Int
    
    @Field(key: "bot_clicks")
    var botClicks: Int
    
    @Timestamp(key: "collected_at", on: .create)
    var collectedAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        postId: UUID,
        views: Int = 0,
        reads: Int = 0,
        readPercentage: Double = 0.0,
        likes: Int = 0,
        comments: Int = 0,
        shares: Int = 0,
        botClicks: Int = 0
    ) {
        self.id = id
        self.$post.id = postId
        self.views = views
        self.reads = reads
        self.readPercentage = readPercentage
        self.likes = likes
        self.comments = comments
        self.shares = shares
        self.botClicks = botClicks
    }
}

