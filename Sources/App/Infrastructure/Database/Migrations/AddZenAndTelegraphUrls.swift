import Fluent

struct AddZenAndTelegraphUrls: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("zen_posts")
            .field("zen_article_url", .string)
            .field("telegraph_url", .string)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("zen_posts")
            .deleteField("zen_article_url")
            .deleteField("telegraph_url")
            .update()
    }
}

