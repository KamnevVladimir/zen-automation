import Fluent

struct CreateTrendingDestinations: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("trending_destinations")
            .id()
            .field("destination", .string, .required)
            .field("country", .string, .required)
            .field("search_count", .int, .required)
            .field("avg_price", .int)
            .field("price_trend", .string)
            .field("last_updated", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("trending_destinations").delete()
    }
}

