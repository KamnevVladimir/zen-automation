import Fluent

struct CreateZenPosts: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("zen_posts")
            .id()
            .field("title", .string, .required)
            .field("subtitle", .string)
            .field("body", .string, .required)
            .field("tags", .array(of: .string), .required)
            .field("meta_description", .string)
            .field("template_type", .string, .required)
            .field("status", .string, .required)
            .field("published_at", .datetime)
            .field("zen_article_id", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
        
        // Индексы
        try await database.schema("zen_posts")
            .unique(on: "zen_article_id")
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("zen_posts").delete()
    }
}

