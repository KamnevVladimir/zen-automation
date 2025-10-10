import Fluent

struct CreateZenImages: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("zen_images")
            .id()
            .field("post_id", .uuid, .required, .references("zen_posts", "id", onDelete: .cascade))
            .field("url", .string, .required)
            .field("prompt", .string, .required)
            .field("dalle_id", .string)
            .field("position", .int, .required)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("zen_images").delete()
    }
}

