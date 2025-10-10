import Foundation

/// Оптимизатор вирусного контента для Яндекс Дзен
final class ViralContentOptimizer {
    
    // MARK: - Вирусные триггеры для Дзена
    
    struct ViralScore {
        let overall: Double // 0.0-1.0
        let emotionalAppeal: Double
        let curiosityGap: Double
        let socialProof: Double
        let urgency: Double
        let specificity: Double
        let readability: Double
        let shareability: Double
        
        var recommendations: [String]
    }
    
    /// Анализ вирусного потенциала заголовка
    func analyzeTitle(_ title: String) -> ViralScore {
        var scores: [String: Double] = [:]
        var recommendations: [String] = []
        
        // 1. Эмоциональная привлекательность
        let emotionalWords = [
            "шокирующ", "невероятн", "удивительн", "секрет", "тайн",
            "простой способ", "легко", "быстро", "дешев", "бесплатн",
            "экономи", "сэкономил", "как я", "мой опыт", "честно"
        ]
        let emotionalScore = emotionalWords.reduce(0.0) { score, word in
            title.lowercased().contains(word) ? score + 0.15 : score
        }
        scores["emotional"] = min(emotionalScore, 1.0)
        
        if emotionalScore < 0.3 {
            recommendations.append("Добавьте эмоциональные слова (секрет, удивительно, шокирующе)")
        }
        
        // 2. Curiosity Gap (незавершённость)
        let curiosityPatterns = [
            "почему", "как", "что будет если", "топ ", "лучш",
            "никто не расскаж", "то, что", "вы не знали"
        ]
        let curiosityScore = curiosityPatterns.reduce(0.0) { score, pattern in
            title.lowercased().contains(pattern) ? score + 0.2 : score
        }
        scores["curiosity"] = min(curiosityScore, 1.0)
        
        if curiosityScore < 0.3 {
            recommendations.append("Создайте 'gap' - незавершённость, которая заставит кликнуть")
        }
        
        // 3. Конкретность и числа
        let hasNumbers = title.range(of: "\\d+", options: .regularExpression) != nil
        let specificityScore = hasNumbers ? 0.8 : 0.2
        scores["specificity"] = specificityScore
        
        if !hasNumbers {
            recommendations.append("Добавьте конкретное число (7 способов, 3 ошибки, 50% скидка)")
        }
        
        // 4. Социальное доказательство
        let socialProofWords = ["проверен", "тысячи", "миллион", "все", "большинство"]
        let socialScore = socialProofWords.reduce(0.0) { score, word in
            title.lowercased().contains(word) ? score + 0.25 : score
        }
        scores["social"] = min(socialScore, 1.0)
        
        // 5. Срочность
        let urgencyWords = ["сейчас", "сегодня", "до конца", "осталось", "2025", "новинк"]
        let urgencyScore = urgencyWords.reduce(0.0) { score, word in
            title.lowercased().contains(word) ? score + 0.2 : score
        }
        scores["urgency"] = min(urgencyScore, 1.0)
        
        // 6. Читаемость (длина заголовка)
        let titleLength = title.count
        let readabilityScore: Double
        if titleLength >= 40 && titleLength <= 100 {
            readabilityScore = 1.0
        } else if titleLength < 20 || titleLength > 140 {
            readabilityScore = 0.3
        } else {
            readabilityScore = 0.7
        }
        scores["readability"] = readabilityScore
        
        if titleLength < 40 {
            recommendations.append("Заголовок слишком короткий - добавьте деталей (идеально 50-100 символов)")
        } else if titleLength > 100 {
            recommendations.append("Заголовок слишком длинный - сократите до 100 символов")
        }
        
        // 7. Shareability (желание поделиться)
        let shareWords = ["не поверите", "вы должны знать", "каждый должен", "это изменит"]
        let shareScore = shareWords.reduce(0.0) { score, word in
            title.lowercased().contains(word) ? score + 0.25 : score
        }
        scores["share"] = min(shareScore, 1.0)
        
        // Итоговая оценка
        let overallScore = scores.values.reduce(0.0, +) / Double(scores.count)
        
        return ViralScore(
            overall: overallScore,
            emotionalAppeal: scores["emotional"] ?? 0,
            curiosityGap: scores["curiosity"] ?? 0,
            socialProof: scores["social"] ?? 0,
            urgency: scores["urgency"] ?? 0,
            specificity: scores["specificity"] ?? 0,
            readability: scores["readability"] ?? 0,
            shareability: scores["share"] ?? 0,
            recommendations: recommendations
        )
    }
    
    /// Генерация вирусного заголовка на основе темы
    func generateViralTitle(topic: String, category: PostCategory) -> [String] {
        var variants: [String] = []
        
        switch category {
        case .destination:
            variants = [
                "🔥 \(topic): я слетал за 15к₽ и вот что увидел",
                "Почему никто не рассказывает про \(topic) в 2025?",
                "7 секретов \(topic), о которых молчат туроператоры",
                "\(topic): что будет, если полететь в низкий сезон?",
                "Я потратил 3 дня в \(topic) - честный отзыв без прикрас"
            ]
            
        case .lifehack:
            variants = [
                "🎯 5 способов сэкономить 50% на авиабилетах в 2025",
                "Простой трюк с билетами, который знают только агенты",
                "Как я летаю бизнес-классом по цене эконома",
                "Этот секрет авиакомпании не хотят, чтобы вы знали",
                "7 ошибок при покупке билетов, которые стоят вам денег"
            ]
            
        case .comparison:
            variants = [
                "\(topic): честное сравнение цен, погоды и впечатлений",
                "Турция VS Египет 2025: где дешевле и лучше?",
                "Я съездил в оба места - вот неожиданный вердикт",
                "\(topic): что выбирают 90% путешественников?",
                "Шокирующая правда о \(topic) - мой личный опыт"
            ]
            
        case .budget:
            variants = [
                "💰 Отпуск за 30к₽: 5 стран, где это реально в 2025",
                "Как я слетал на море с семьёй за 50 тысяч рублей",
                "Бюджетный отдых: куда поехать, если денег мало",
                "7 недооценённых направлений дешевле Турции",
                "Этот способ сэкономил мне 40% на отпуске"
            ]
            
        case .trending:
            variants = [
                "🔥 ТОП-5 направлений недели: куда летят все прямо сейчас",
                "Новый тренд 2025: почему все едут именно туда",
                "Я узнал, куда летают умные туристы этой зимой",
                "Эти 3 страны взорвали туррынок в январе 2025",
                "Почему все бронируют билеты в \(topic) на февраль?"
            ]
            
        default:
            variants = [
                "🌍 \(topic): всё, что нужно знать в 2025",
                "Честный гайд по \(topic) от бывалого путешественника",
                "Как \(topic) изменит ваш взгляд на отпуск"
            ]
        }
        
        return variants
    }
    
    /// Оптимизация тегов для Дзена (SEO)
    func optimizeTags(for topic: String, category: PostCategory) -> [String] {
        var tags: [String] = []
        
        // Базовые теги
        tags.append("путешествия")
        tags.append("дешевыеполеты")
        tags.append("отпуск2025")
        
        // Категориальные теги
        switch category {
        case .destination:
            tags.append(contentsOf: ["пляжныйотдых", "кудаполететь", "отдыхнаморе"])
        case .lifehack:
            tags.append(contentsOf: ["лайфхаки", "секретыпутешествий", "экономиянаполетах"])
        case .comparison:
            tags.append(contentsOf: ["сравнение", "кудалучше", "выборнаправления"])
        case .budget:
            tags.append(contentsOf: ["бюджетныйотдых", "дешевыйотпуск", "экономия"])
        case .trending:
            tags.append(contentsOf: ["тренды2025", "популярныенаправления", "хитсезона"])
        default:
            tags.append("туризм")
        }
        
        // Сезонные теги
        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth >= 6 && currentMonth <= 8 {
            tags.append("летнийотдых")
        } else if currentMonth >= 12 || currentMonth <= 2 {
            tags.append("зимнийотдых")
        }
        
        // Ограничиваем до 7 тегов (оптимально для Дзена)
        return Array(tags.prefix(7))
    }
    
    /// Добавление призывов к действию (CTA) для увеличения engagement
    func generateEngagementHooks() -> [String] {
        return [
            "\n\n💬 А вы уже были в этой стране? Поделитесь в комментариях своим опытом!",
            "\n\n👉 Сохраните этот пост, чтобы не потерять - пригодится при планировании отпуска!",
            "\n\n❤️ Лайк, если статья была полезной! Ваша поддержка мотивирует меня делиться ещё больше секретов экономии.",
            "\n\n🔔 Подпишитесь, чтобы не пропустить новые лайфхаки по дешёвым путешествиям!",
            "\n\n⚡️ Напишите в комментариях, куда хотите слетать в 2025 - сделаю обзор с актуальными ценами!",
            "\n\n🎯 Какой совет из статьи вы попробуете первым? Делитесь своими планами!"
        ]
    }
}

// MARK: - Расширения для PostCategory

extension PostCategory {
    var viralPotential: Double {
        switch self {
        case .lifehack: return 0.9      // Лайфхаки - самые вирусные
        case .comparison: return 0.85   // Сравнения - высокая вовлечённость
        case .trending: return 0.8      // Тренды - актуальность
        case .budget: return 0.75       // Бюджет - популярная тема
        case .destination: return 0.7   // Направления - средняя вирусность
        default: return 0.5
        }
    }
}

