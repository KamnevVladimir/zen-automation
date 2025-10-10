import Foundation

protocol ContentValidatorProtocol {
    func validate(body: String, tags: [String]) -> ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let score: Double
    let issues: [String]
}

final class ContentValidator: ContentValidatorProtocol {
    private let minLength: Int
    private let maxLength: Int
    private let botUsername: String
    
    init(
        minLength: Int = AppConfig.minPostLength,
        maxLength: Int = AppConfig.maxPostLength,
        botUsername: String = AppConfig.botUsername
    ) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.botUsername = botUsername
    }
    
    func validate(body: String, tags: [String]) -> ValidationResult {
        var issues: [String] = []
        var score: Double = 1.0
        
        // 1. Проверка длины
        if body.count < minLength {
            issues.append("Текст слишком короткий: \(body.count) < \(minLength)")
            score -= 0.3
        }
        
        if body.count > maxLength * 2 {
            issues.append("Текст слишком длинный: \(body.count) > \(maxLength * 2)")
            score -= 0.2
        }
        
        // 2. Проверка структуры
        if !body.contains("##") && !body.contains("<h2>") {
            issues.append("Отсутствуют подзаголовки")
            score -= 0.15
        }
        
        // 3. Проверка интеграции бота
        let botMentions = body.components(separatedBy: "@\(botUsername)").count - 1
        if botMentions == 0 {
            issues.append("Нет упоминания бота @\(botUsername)")
            score -= 0.3
        } else if botMentions > 3 {
            issues.append("Слишком много упоминаний бота: \(botMentions)")
            score -= 0.1
        }
        
        // 4. Проверка на запрещённые слова
        let bannedWords = ["100%", "гарантия", "секрет века", "уникальное предложение"]
        for word in bannedWords {
            if body.lowercased().contains(word.lowercased()) {
                issues.append("Содержит запрещённое слово: \(word)")
                score -= 0.1
            }
        }
        
        // 5. Проверка тегов
        if tags.isEmpty {
            issues.append("Нет тегов")
            score -= 0.1
        } else if tags.count > 10 {
            issues.append("Слишком много тегов: \(tags.count)")
            score -= 0.05
        }
        
        // 6. Проверка качества текста
        let sentences = body.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if sentences.count < 10 {
            issues.append("Слишком мало предложений")
            score -= 0.1
        }
        
        // 7. Проверка на пустые разделы
        if body.contains("TODO") || body.contains("[заполнить]") {
            issues.append("Содержит заполнители")
            score -= 0.4
        }
        
        let finalScore = max(0.0, min(1.0, score))
        let isValid = finalScore >= AppConfig.minQualityScore
        
        return ValidationResult(
            isValid: isValid,
            score: finalScore,
            issues: issues
        )
    }
}

