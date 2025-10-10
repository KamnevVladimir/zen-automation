import Fluent

struct CreatePostTemplates: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("post_templates")
            .id()
            .field("name", .string, .required)
            .field("type", .string, .required)
            .field("system_prompt", .string, .required)
            .field("user_prompt_template", .string, .required)
            .field("image_prompt_template", .string, .required)
            .field("min_length", .int, .required)
            .field("max_length", .int, .required)
            .field("estimated_read_time", .int, .required)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("post_templates").delete()
    }
}

