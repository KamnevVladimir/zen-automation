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
    
    /// Генерация SEO-оптимизированного заголовка с ключевыми словами
    func generateViralTitle(topic: String, category: PostCategory) -> [String] {
        var variants: [String] = []
        
        switch category {
        case .destination:
            variants = [
                "Дешёвые билеты в \(topic) 2025: нашёл за 15000₽ (как сэкономить)",
                "Куда поехать без визы: \(topic) за 20000₽ на двоих",
                "\(topic) 2025: полный гайд по бюджетному отдыху",
                "Отдых в \(topic): цены, маршруты, лайфхаки для путешествий",
                "Безвизовые страны 2025: \(topic) — отзыв и бюджет поездки"
            ]
            
        case .lifehack:
            variants = [
                "Как найти дешёвые билеты: 5 способов экономии до 50% в 2025",
                "Авиабилеты со скидкой: проверенный лайфхак поиска выгодных цен",
                "Дешёвые авиабилеты 2025: секреты которые экономят 30-40%",
                "Где искать дешёвые билеты: топ-7 сервисов и лайфхаков",
                "Как купить билеты дёшево: ошибки которые стоят вам денег"
            ]
            
        case .comparison:
            variants = [
                "Куда лучше поехать в 2025: \(topic) — сравнение цен и впечатлений",
                "Турция или Египет 2025: где дешевле отдых на море",
                "\(topic): честное сравнение бюджета путешествия",
                "Куда поехать отдыхать в 2025: выбор между \(topic)",
                "Бюджетный отдых 2025: \(topic) — что выгоднее"
            ]
            
        case .budget:
            variants = [
                "Бюджетное путешествие 2025: топ-5 стран дешевле 30000₽",
                "Куда слетать дёшево: отдых на море за 50000₽ на семью",
                "Дешёвый отдых за границей 2025: куда поехать без переплат",
                "Бюджетные направления 2025: страны дешевле Турции",
                "Как сэкономить на отпуске: бюджетные страны для отдыха"
            ]
            
        case .trending:
            variants = [
                "Куда поехать в 2025: топ-5 популярных направлений для отдыха",
                "Лучшие направления для путешествий 2025: куда летят все",
                "Популярные страны для отдыха 2025: тренды путешествий",
                "Куда поехать зимой 2025: топ-3 бюджетных направления",
                "Модные направления 2025: куда едут умные туристы"
            ]
            
        default:
            variants = [
                "\(topic): полный гайд для путешествий в 2025",
                "Путешествие в \(topic): советы и лайфхаки для туристов",
                "\(topic) 2025: что нужно знать перед поездкой"
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

