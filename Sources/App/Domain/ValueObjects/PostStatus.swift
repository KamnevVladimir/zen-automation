import Foundation

enum PostStatus: String, Codable {
    case draft = "draft"
    case published = "published"
    case failed = "failed"
    case pending = "pending"
}

