import Foundation
import Vapor
import Fluent

/// Сервис проверки уникальности контента для предотвращения дублирования
final class UniquenessChecker {
    private let db: Database
    private let logger: Logger
    
    init(db: Database, logger: Logger) {
        self.db = db
        self.logger = logger
    }
    
    /// Проверяет уникальность нового поста против существующих
    func checkUniqueness(
        title: String,
        content: String,
        category: PostCategory,
        topic: String
    ) async throws -> UniquenessResult {
        
        logger.info("🔍 Проверяю уникальность поста: \(title)")
        
        // 1. Получаем существующие посты за последние 30 дней
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentPosts = try await ZenPostModel.query(on: db)
            .filter(\.$createdAt >= thirtyDaysAgo)
            .all()
        
        logger.info("📚 Найдено постов за 30 дней: \(recentPosts.count)")
        
        // 2. Проверяем заголовки на схожесть
        let titleSimilarity = checkTitleSimilarity(title: title, existingPosts: recentPosts)
        
        // 3. Проверяем контент на схожесть
        let contentSimilarity = checkContentSimilarity(content: content, existingPosts: recentPosts)
        
        // 4. Проверяем тематическое дублирование
        let topicDuplication = checkTopicDuplication(topic: topic, category: category, existingPosts: recentPosts)
        
        // 5. Проверяем сезонные ограничения
        let seasonalRestriction = checkSeasonalRestrictions(topic: topic, category: category, existingPosts: recentPosts)
        
        // 6. Вычисляем общую оценку уникальности
        let overallScore = calculateUniquenessScore(
            titleSimilarity: titleSimilarity,
            contentSimilarity: contentSimilarity,
            topicDuplication: topicDuplication,
            seasonalRestriction: seasonalRestriction
        )
        
        let isUnique = overallScore >= 0.7 // Порог уникальности 70%
        
        let recommendations = generateRecommendations(
            titleSimilarity: titleSimilarity,
            contentSimilarity: contentSimilarity,
            topicDuplication: topicDuplication,
            seasonalRestriction: seasonalRestriction
        )
        
        logger.info("✅ Уникальность: \(String(format: "%.1f%%", overallScore * 100))")
        
        return UniquenessResult(
            isUnique: isUnique,
            score: overallScore,
            titleSimilarity: titleSimilarity,
            contentSimilarity: contentSimilarity,
            topicDuplication: topicDuplication,
            seasonalRestriction: seasonalRestriction,
            recommendations: recommendations
        )
    }
    
    // MARK: - Private Methods
    
    private func checkTitleSimilarity(title: String, existingPosts: [ZenPostModel]) -> Double {
        let titleWords = Set(title.lowercased().components(separatedBy: .whitespacesAndPunctuation))
        
        var maxSimilarity: Double = 0
        
        for post in existingPosts {
            let existingWords = Set(post.title.lowercased().components(separatedBy: .whitespacesAndPunctuation))
            
            // Вычисляем коэффициент Жаккара
            let intersection = titleWords.intersection(existingWords)
            let union = titleWords.union(existingWords)
            
            let similarity = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
            maxSimilarity = max(maxSimilarity, similarity)
        }
        
        return maxSimilarity
    }
    
    private func checkContentSimilarity(content: String, existingPosts: [ZenPostModel]) -> Double {
        let contentWords = Set(content.lowercased().components(separatedBy: .whitespacesAndPunctuation))
        
        var maxSimilarity: Double = 0
        
        for post in existingPosts {
            let existingWords = Set(post.fullPost?.lowercased().components(separatedBy: .whitespacesAndPunctuation) ?? [])
            
            // Проверяем только если контент достаточно длинный
            if existingWords.count < 50 { continue }
            
            let intersection = contentWords.intersection(existingWords)
            let union = contentWords.union(existingWords)
            
            let similarity = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
            maxSimilarity = max(maxSimilarity, similarity)
        }
        
        return maxSimilarity
    }
    
    private func checkTopicDuplication(topic: String, category: PostCategory, existingPosts: [ZenPostModel]) -> Double {
        let recentPostsInCategory = existingPosts.filter { $0.templateType == category.rawValue }
        
        // Проверяем повторение темы в той же категории
        let topicWords = Set(topic.lowercased().components(separatedBy: .whitespacesAndPunctuation))
        
        var duplicationCount = 0
        
        for post in recentPostsInCategory {
            let postTitleWords = Set(post.title.lowercased().components(separatedBy: .whitespacesAndPunctuation))
            let intersection = topicWords.intersection(postTitleWords)
            
            // Если пересечение больше 50% слов - считаем дублированием
            if Double(intersection.count) / Double(topicWords.count) > 0.5 {
                duplicationCount += 1
            }
        }
        
        // Возвращаем коэффициент дублирования (0 = нет дублей, 1 = много дублей)
        return min(1.0, Double(duplicationCount) / 3.0) // Максимум 3 дубля = 100%
    }
    
    private func checkSeasonalRestrictions(topic: String, category: PostCategory, existingPosts: [ZenPostModel]) -> Double {
        let _ = Calendar.current.component(.month, from: Date())
        
        // Сезонные темы не должны повторяться чаще чем раз в 2 месяца
        let seasonalTopics = [
            "зимний отдых", "летний отдых", "весенний отдых", "осенний отдых",
            "новый год", "майские праздники", "бархатный сезон"
        ]
        
        let isSeasonalTopic = seasonalTopics.contains { topic.lowercased().contains($0) }
        
        if !isSeasonalTopic { return 0.0 }
        
        // Проверяем, была ли похожая сезонная тема в последние 2 месяца
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        
        let recentSeasonalPosts = existingPosts.filter { post in
            guard let createdAt = post.createdAt else { return false }
            return createdAt >= twoMonthsAgo && 
                   seasonalTopics.contains { post.title.lowercased().contains($0) }
        }
        
        return recentSeasonalPosts.isEmpty ? 0.0 : 0.8
    }
    
    private func calculateUniquenessScore(
        titleSimilarity: Double,
        contentSimilarity: Double,
        topicDuplication: Double,
        seasonalRestriction: Double
    ) -> Double {
        // Веса для разных типов проверок
        let titleWeight = 0.3
        let contentWeight = 0.4
        let topicWeight = 0.2
        let seasonalWeight = 0.1
        
        // Вычисляем общую оценку (чем меньше схожести, тем выше уникальность)
        let score = (1.0 - titleSimilarity) * titleWeight +
                   (1.0 - contentSimilarity) * contentWeight +
                   (1.0 - topicDuplication) * topicWeight +
                   (1.0 - seasonalRestriction) * seasonalWeight
        
        return max(0.0, min(1.0, score))
    }
    
    private func generateRecommendations(
        titleSimilarity: Double,
        contentSimilarity: Double,
        topicDuplication: Double,
        seasonalRestriction: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        if titleSimilarity > 0.6 {
            recommendations.append("Заголовок слишком похож на существующие. Измените формулировку или угол подачи.")
        }
        
        if contentSimilarity > 0.5 {
            recommendations.append("Контент имеет высокую схожесть с предыдущими постами. Добавьте уникальные детали и личный опыт.")
        }
        
        if topicDuplication > 0.5 {
            recommendations.append("Тема уже недавно освещалась. Выберите другой аспект или подождите 1-2 недели.")
        }
        
        if seasonalRestriction > 0.5 {
            recommendations.append("Сезонная тема недавно публиковалась. Рассмотрите другую сезонную тему или подождите.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Пост уникален и готов к публикации!")
        }
        
        return recommendations
    }
}

// MARK: - Models

struct UniquenessResult {
    let isUnique: Bool
    let score: Double // 0.0 - 1.0
    let titleSimilarity: Double
    let contentSimilarity: Double
    let topicDuplication: Double
    let seasonalRestriction: Double
    let recommendations: [String]
}

// MARK: - Extensions

extension CharacterSet {
    static let whitespacesAndPunctuation = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
}
