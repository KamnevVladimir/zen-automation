import Fluent

struct CreateZenMetrics: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("zen_metrics")
            .id()
            .field("post_id", .uuid, .required, .references("zen_posts", "id", onDelete: .cascade))
            .field("views", .int, .required)
            .field("reads", .int, .required)
            .field("read_percentage", .double, .required)
            .field("likes", .int, .required)
            .field("comments", .int, .required)
            .field("shares", .int, .required)
            .field("bot_clicks", .int, .required)
            .field("collected_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("zen_metrics").delete()
    }
}

