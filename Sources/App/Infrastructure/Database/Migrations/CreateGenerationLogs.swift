import Fluent

struct CreateGenerationLogs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("generation_logs")
            .id()
            .field("post_id", .uuid, .references("zen_posts", "id", onDelete: .cascade))
            .field("step", .string, .required)
            .field("status", .string, .required)
            .field("error_message", .string)
            .field("duration_ms", .int)
            .field("cost_usd", .double)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("generation_logs").delete()
    }
}

