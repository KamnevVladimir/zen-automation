import Foundation
import Vapor
import Fluent

/// Оптимизатор контента для попадания в чарты Яндекс Дзен
final class TrendingOptimizer {
    private let db: Database
    private let logger: Logger
    
    init(db: Database, logger: Logger) {
        self.db = db
        self.logger = logger
    }
    
    /// Оптимизирует контент для максимального попадания в чарты
    func optimizeForTrending(
        content: inout GeneratedContent,
        category: PostCategory
    ) async throws -> TrendingOptimizationResult {
        
        logger.info("📈 Оптимизирую контент для попадания в чарты")
        
        // 1. Анализируем текущие тренды
        let currentTrends = try await analyzeCurrentTrends()
        
        // 2. Оптимизируем заголовок
        let optimizedTitle = optimizeTitle(content.title, trends: currentTrends, category: category)
        
        // 3. Оптимизируем теги
        let optimizedTags = optimizeTags(content.tags, trends: currentTrends, category: category)
        
        // 4. Добавляем вирусные элементы
        let viralElements = addViralElements(to: content, category: category)
        
        // 5. Оптимизируем время публикации
        let optimalPublishTime = calculateOptimalPublishTime()
        
        // 6. Добавляем engagement-элементы
        let engagementElements = addEngagementElements(to: content, category: category)
        
        // Обновляем контент
        content.title = optimizedTitle
        content.tags = optimizedTags
        
        let result = TrendingOptimizationResult(
            originalTitle: content.title,
            optimizedTitle: optimizedTitle,
            originalTags: content.tags,
            optimizedTags: optimizedTags,
            viralElements: viralElements,
            optimalPublishTime: optimalPublishTime,
            engagementElements: engagementElements,
            trendingScore: calculateTrendingScore(
                title: optimizedTitle,
                tags: optimizedTags,
                viralElements: viralElements,
                trends: currentTrends
            )
        )
        
        logger.info("✅ Оптимизация завершена. Trending score: \(String(format: "%.1f%%", result.trendingScore * 100))")
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func analyzeCurrentTrends() async throws -> [TrendingTopic] {
        // Анализируем популярные темы за последние 7 дней
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let recentPosts = try await ZenPostModel.query(on: db)
            .filter(\.$createdAt >= sevenDaysAgo)
            .filter(\.$status == .published)
            .all()
        
        // Анализируем популярные теги
        let tagFrequency = analyzeTagFrequency(in: recentPosts)
        
        // Анализируем популярные слова в заголовках
        let titleWords = analyzeTitleWords(in: recentPosts)
        
        // Анализируем популярные направления
        let popularDestinations = analyzePopularDestinations(in: recentPosts)
        
        return [
            TrendingTopic(type: .tags, keywords: Array(tagFrequency.prefix(10))),
            TrendingTopic(type: .words, keywords: Array(titleWords.prefix(10))),
            TrendingTopic(type: .destinations, keywords: Array(popularDestinations.prefix(10)))
        ]
    }
    
    private func analyzeTagFrequency(in posts: [ZenPostModel]) -> [(String, Int)] {
        var tagCount: [String: Int] = [:]
        
        for post in posts {
            for tag in post.tags {
                tagCount[tag, default: 0] += 1
            }
        }
        
        return tagCount.sorted { $0.value > $1.value }
    }
    
    private func analyzeTitleWords(in posts: [ZenPostModel]) -> [(String, Int)] {
        var wordCount: [String: Int] = [:]
        
        for post in posts {
            let words = post.title.lowercased()
                .components(separatedBy: .whitespacesAndPunctuationTrending)
                .filter { $0.count > 3 } // Только слова длиннее 3 символов
            
            for word in words {
                wordCount[word, default: 0] += 1
            }
        }
        
        return wordCount.sorted { $0.value > $1.value }
    }
    
    private func analyzePopularDestinations(in posts: [ZenPostModel]) -> [(String, Int)] {
        let destinations = [
            "Турция", "Египет", "ОАЭ", "Таиланд", "Вьетнам", "Грузия",
            "Армения", "Узбекистан", "Казахстан", "Азербайджан",
            "Португалия", "Испания", "Италия", "Кипр", "Греция",
            "Дубай", "Оман", "Бали", "Мальдивы", "Сейшелы"
        ]
        
        var destinationCount: [String: Int] = [:]
        
        for post in posts {
            for destination in destinations {
                if post.title.lowercased().contains(destination.lowercased()) {
                    destinationCount[destination, default: 0] += 1
                }
            }
        }
        
        return destinationCount.sorted { $0.value > $1.value }
    }
    
    private func optimizeTitle(_ title: String, trends: [TrendingTopic], category: PostCategory) -> String {
        let _ = title
        
        // Добавляем трендовые слова в заголовок
        let trendingWords = trends.first { $0.type == .words }?.keywords.prefix(3) ?? []
        let trendingTags = trends.first { $0.type == .tags }?.keywords.prefix(2) ?? []
        
        // Создаём варианты заголовка с трендовыми элементами
        let titleVariants = generateTitleVariants(
            baseTitle: title,
            trendingWords: Array(trendingWords),
            trendingTags: Array(trendingTags),
            category: category
        )
        
        // Выбираем лучший вариант по вирусному потенциалу
        let bestVariant = selectBestTitle(from: titleVariants)
        
        return bestVariant
    }
    
    private func generateTitleVariants(
        baseTitle: String,
        trendingWords: [(String, Int)],
        trendingTags: [(String, Int)],
        category: PostCategory
    ) -> [String] {
        var variants: [String] = []
        
        // Оригинальный заголовок
        variants.append(baseTitle)
        
        // Добавляем трендовые слова
        for (word, _) in trendingWords.prefix(2) {
            if !baseTitle.lowercased().contains(word.lowercased()) {
                let variant = "\(baseTitle) \(word)"
                variants.append(variant)
            }
        }
        
        // Добавляем трендовые теги
        for (tag, _) in trendingTags.prefix(1) {
            if !baseTitle.lowercased().contains(tag.lowercased()) {
                let variant = "\(tag): \(baseTitle)"
                variants.append(variant)
            }
        }
        
        // Добавляем сезонные элементы
        let currentMonth = Calendar.current.component(.month, from: Date())
        let seasonalElement = getSeasonalElement(for: currentMonth)
        if let element = seasonalElement, !baseTitle.lowercased().contains(element.lowercased()) {
            let variant = "\(baseTitle) \(element)"
            variants.append(variant)
        }
        
        // Добавляем эмоциональные усилители
        let emotionalBoosters = ["2025", "секрет", "лайфхак", "проверено", "реально"]
        for booster in emotionalBoosters.prefix(2) {
            if !baseTitle.lowercased().contains(booster.lowercased()) {
                let variant = "\(booster) \(baseTitle)"
                variants.append(variant)
            }
        }
        
        return variants
    }
    
    private func selectBestTitle(from variants: [String]) -> String {
        var bestTitle = variants.first ?? ""
        var bestScore = 0.0
        
        for variant in variants {
            let score = calculateTitleScore(variant)
            if score > bestScore {
                bestScore = score
                bestTitle = variant
            }
        }
        
        return bestTitle
    }
    
    private func calculateTitleScore(_ title: String) -> Double {
        var score = 0.0
        
        // Длина заголовка (оптимально 50-100 символов)
        let length = title.count
        if length >= 50 && length <= 100 {
            score += 0.3
        } else if length >= 40 && length <= 120 {
            score += 0.2
        }
        
        // Наличие чисел
        if title.range(of: "\\d+", options: .regularExpression) != nil {
            score += 0.2
        }
        
        // Наличие эмоциональных слов
        let emotionalWords = ["секрет", "лайфхак", "проверено", "реально", "удивительно", "шокирующе"]
        for word in emotionalWords {
            if title.lowercased().contains(word) {
                score += 0.1
            }
        }
        
        // Наличие ключевых слов для путешествий
        let travelKeywords = ["билеты", "путешествие", "отдых", "дешёвые", "бюджет", "куда поехать"]
        for keyword in travelKeywords {
            if title.lowercased().contains(keyword) {
                score += 0.1
            }
        }
        
        return min(score, 1.0)
    }
    
    private func optimizeTags(_ tags: [String], trends: [TrendingTopic], category: PostCategory) -> [String] {
        var optimizedTags = tags
        
        // Добавляем трендовые теги
        let trendingTags = trends.first { $0.type == .tags }?.keywords.prefix(3) ?? []
        for (tag, _) in trendingTags {
            if !optimizedTags.contains(tag) {
                optimizedTags.append(tag)
            }
        }
        
        // Добавляем сезонные теги
        let currentMonth = Calendar.current.component(.month, from: Date())
        let seasonalTag = getSeasonalTag(for: currentMonth)
        if let tag = seasonalTag, !optimizedTags.contains(tag) {
            optimizedTags.append(tag)
        }
        
        // Добавляем категориальные теги
        let categoryTags = getCategoryTags(for: category)
        for tag in categoryTags {
            if !optimizedTags.contains(tag) {
                optimizedTags.append(tag)
            }
        }
        
        // Ограничиваем до 7 тегов (оптимально для Дзена)
        return Array(optimizedTags.prefix(7))
    }
    
    private func addViralElements(to content: GeneratedContent, category: PostCategory) -> [String] {
        var viralElements: [String] = []
        
        // Добавляем вирусные фразы в зависимости от категории
        switch category {
        case .lifehack:
            viralElements = [
                "секрет который знают только стюардессы",
                "лайфхак который сэкономит вам 50%",
                "трюк который работает в 100% случаев"
            ]
        case .comparison:
            viralElements = [
                "честное сравнение без воды",
                "результат вас удивит",
                "я сам не ожидал такого"
            ]
        case .budget:
            viralElements = [
                "реальный бюджет с чеками",
                "сколько я потратил на самом деле",
                "неожиданные траты о которых молчат"
            ]
        case .trending:
            viralElements = [
                "тренд который взорвал интернет",
                "все уже бронируют",
                "пока не стало слишком популярно"
            ]
        default:
            viralElements = [
                "личный опыт",
                "проверено на себе",
                "рекомендую"
            ]
        }
        
        return viralElements
    }
    
    private func calculateOptimalPublishTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Оптимальное время для Дзена: 8:00-10:00 и 18:00-20:00
        let optimalHours = [8, 9, 18, 19, 20]
        
        for hour in optimalHours {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = 0
            components.second = 0
            
            if let optimalTime = calendar.date(from: components), optimalTime > now {
                return optimalTime
            }
        }
        
        // Если все оптимальные времена прошли, берём завтра в 8:00
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 8
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? now
    }
    
    private func addEngagementElements(to content: GeneratedContent, category: PostCategory) -> [String] {
        let engagementElements = [
            "💬 Поделитесь в комментариях своим опытом!",
            "❤️ Лайк, если статья была полезной!",
            "🔔 Подпишитесь, чтобы не пропустить новые лайфхаки!",
            "⚡️ Напишите, куда хотите слетать в 2025!",
            "🎯 Какой совет попробуете первым?",
            "📌 Сохраните пост, чтобы не потерять!"
        ]
        
        return Array(engagementElements.shuffled().prefix(2))
    }
    
    private func calculateTrendingScore(
        title: String,
        tags: [String],
        viralElements: [String],
        trends: [TrendingTopic]
    ) -> Double {
        var score = 0.0
        
        // Оценка заголовка (40%)
        score += calculateTitleScore(title) * 0.4
        
        // Оценка тегов (30%)
        let trendingTags = trends.first { $0.type == .tags }?.keywords.map { $0.0 } ?? []
        let tagScore = tags.reduce(0.0) { score, tag in
            trendingTags.contains(tag) ? score + 0.1 : score
        }
        score += min(tagScore, 1.0) * 0.3
        
        // Оценка вирусных элементов (20%)
        let viralScore = viralElements.isEmpty ? 0.0 : 1.0
        score += viralScore * 0.2
        
        // Оценка актуальности (10%)
        let currentYear = Calendar.current.component(.year, from: Date())
        let relevanceScore = title.contains("\(currentYear)") ? 1.0 : 0.5
        score += relevanceScore * 0.1
        
        return min(score, 1.0)
    }
    
    private func getSeasonalElement(for month: Int) -> String? {
        switch month {
        case 12, 1, 2: return "зимой 2025"
        case 3, 4, 5: return "весной 2025"
        case 6, 7, 8: return "летом 2025"
        case 9, 10, 11: return "осенью 2025"
        default: return nil
        }
    }
    
    private func getSeasonalTag(for month: Int) -> String? {
        switch month {
        case 12, 1, 2: return "зимнийотдых2025"
        case 3, 4, 5: return "весеннийотдых2025"
        case 6, 7, 8: return "летнийотдых2025"
        case 9, 10, 11: return "осеннийотдых2025"
        default: return nil
        }
    }
    
    private func getCategoryTags(for category: PostCategory) -> [String] {
        switch category {
        case .lifehack: return ["лайфхаки2025", "секретыпутешествий"]
        case .comparison: return ["сравнение2025", "выборнаправления"]
        case .budget: return ["бюджетныйотдых2025", "экономия"]
        case .trending: return ["тренды2025", "популярныенаправления"]
        case .destination: return ["направления2025", "кудаполететь"]
        case .season: return ["сезонныйотдых2025"]
        case .weekend: return ["выходные2025", "короткиепоездки"]
        case .mistake: return ["ошибкитуристов", "чтонестоитделать"]
        case .hiddenGem: return ["скрытыежемчужины", "малоизвестныеместа"]
        case .visaFree: return ["безвизовыестраны2025"]
        }
    }
}

// MARK: - Models

struct TrendingTopic {
    enum TopicType {
        case tags
        case words
        case destinations
    }
    
    let type: TopicType
    let keywords: [(String, Int)] // (keyword, frequency)
}

struct TrendingOptimizationResult {
    let originalTitle: String
    let optimizedTitle: String
    let originalTags: [String]
    let optimizedTags: [String]
    let viralElements: [String]
    let optimalPublishTime: Date
    let engagementElements: [String]
    let trendingScore: Double
}

// MARK: - Extensions

extension CharacterSet {
    static let whitespacesAndPunctuationTrending = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
}
