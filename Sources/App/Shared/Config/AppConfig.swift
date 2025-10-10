import Vapor

struct AppConfig {
    // OpenAI
    static var openAIKey: String {
        Environment.get("OPENAI_API_KEY") ?? ""
    }
    
    static var openAIModel: String {
        Environment.get("OPENAI_MODEL") ?? "gpt-4-turbo-preview"
    }
    
    static var openAIMaxTokens: Int {
        Int(Environment.get("OPENAI_MAX_TOKENS") ?? "4000") ?? 4000
    }
    
    static var openAITemperature: Double {
        Double(Environment.get("OPENAI_TEMPERATURE") ?? "0.7") ?? 0.7
    }
    
    // DALL-E
    static var dalleModel: String {
        Environment.get("DALLE_MODEL") ?? "dall-e-3"
    }
    
    static var dalleSize: String {
        Environment.get("DALLE_SIZE") ?? "1792x1024"
    }
    
    static var dalleQuality: String {
        Environment.get("DALLE_QUALITY") ?? "hd"
    }
    
    // Telegram
    static var telegramToken: String {
        Environment.get("TELEGRAM_BOT_TOKEN") ?? ""
    }
    
    static var telegramAdminChatId: String {
        Environment.get("TELEGRAM_ADMIN_CHAT_ID") ?? ""
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

