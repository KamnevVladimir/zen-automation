import Vapor

struct AppConfig {
    // Anthropic Claude (единственный AI провайдер)
    static var anthropicKey: String {
        Environment.get("ANTHROPIC_API_KEY") ?? ""
    }
    
    static var anthropicModel: String {
        Environment.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-5-20250929"
    }
    
    static var maxTokens: Int {
        Int(Environment.get("MAX_TOKENS") ?? "4000") ?? 4000
    }
    
    static var temperature: Double {
        Double(Environment.get("TEMPERATURE") ?? "0.7") ?? 0.7
    }
    
    // Stability AI (единственный провайдер изображений)
    static var stabilityAIKey: String {
        Environment.get("STABILITY_AI_KEY") ?? ""
    }
    
    // Telegram
    static var telegramToken: String {
        Environment.get("TELEGRAM_BOT_TOKEN") ?? ""
    }
    
    static var telegramAdminChatId: String {
        Environment.get("TELEGRAM_ADMIN_CHAT_ID") ?? ""
    }
    
    // Telegram Channel для публикации (импорт в Дзен)
    static var telegramChannelId: String {
        Environment.get("TELEGRAM_CHANNEL_ID") ?? ""
    }
    
    // Admin User ID для управления ботом
    static var adminUserId: Int {
        Int(Environment.get("TELEGRAM_ADMIN_USER_ID") ?? "434250421") ?? 434250421
    }
    
    // Bot Integration
    static var botUsername: String {
        Environment.get("BOT_USERNAME") ?? "gdeVacationBot"
    }
    
    static var botDeepLinkBase: String {
        Environment.get("BOT_DEEP_LINK_BASE") ?? "https://t.me/gdeVacationBot?start="
    }
    
    // Content Settings
    static var postsPerDay: Int {
        Int(Environment.get("POSTS_PER_DAY") ?? "4") ?? 4
    }
    
    static var minPostLength: Int {
        Int(Environment.get("MIN_POST_LENGTH") ?? "3000") ?? 3000
    }
    
    static var maxPostLength: Int {
        Int(Environment.get("MAX_POST_LENGTH") ?? "7000") ?? 7000
    }
    
    static var imagesPerPost: String {
        Environment.get("IMAGES_PER_POST") ?? "2-3"
    }
    
    // Scheduler
    static var schedulerTimes: [String] {
        Environment.get("SCHEDULER_TIMES")?.split(separator: ",").map(String.init) ?? ["08:00", "12:00", "16:00", "20:00"]
    }
    
    static var schedulerTimezone: String {
        Environment.get("SCHEDULER_TIMEZONE") ?? "Europe/Moscow"
    }
    
    // Quality Control
    static var enableContentValidation: Bool {
        Environment.get("ENABLE_CONTENT_VALIDATION") == "true"
    }
    
    static var minQualityScore: Double {
        Double(Environment.get("MIN_QUALITY_SCORE") ?? "0.7") ?? 0.7
    }
}

