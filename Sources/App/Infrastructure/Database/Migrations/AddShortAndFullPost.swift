import Fluent

struct AddShortAndFullPost: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zen_posts")
            .field("short_post", .string)
            .field("full_post", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("zen_posts")
            .deleteField("short_post")
            .deleteField("full_post")
            .update()
    }
}
