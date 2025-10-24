import Foundation
import Vapor
import Fluent

/// Динамический генератор тем с учётом актуальности, сезонности и уникальности
final class DynamicTopicGenerator {
    private let db: Database
    private let logger: Logger
    private let uniquenessChecker: UniquenessChecker
    
    init(db: Database, logger: Logger) {
        self.db = db
        self.logger = logger
        self.uniquenessChecker = UniquenessChecker(db: db, logger: logger)
    }
    
    /// Генерирует уникальную тему для поста с учётом всех ограничений
    func generateUniqueTopic(
        for category: PostCategory,
        maxAttempts: Int = 5
    ) async throws -> String {
        
        logger.info("🎯 Генерирую уникальную тему для категории: \(category.rawValue)")
        
        for attempt in 1...maxAttempts {
            logger.info("🔄 Попытка \(attempt)/\(maxAttempts)")
            
            // 1. Генерируем базовую тему
            let baseTopic = generateBaseTopic(for: category)
            
            // 2. Добавляем актуальные элементы
            let enhancedTopic = enhanceWithCurrentTrends(baseTopic, category: category)
            
            // 3. Добавляем сезонные элементы
            let seasonalTopic = addSeasonalElements(enhancedTopic, category: category)
            
            // 4. Проверяем уникальность
            let uniquenessResult = try await uniquenessChecker.checkUniqueness(
                title: seasonalTopic,
                content: "", // Проверяем только заголовок на этом этапе
                category: category,
                topic: seasonalTopic
            )
            
            if uniquenessResult.isUnique {
                logger.info("✅ Найдена уникальная тема: \(seasonalTopic)")
                return seasonalTopic
            } else {
                logger.warning("⚠️ Тема не уникальна (score: \(String(format: "%.1f%%", uniquenessResult.score * 100)))")
                logger.info("💡 Рекомендации: \(uniquenessResult.recommendations.joined(separator: ", "))")
            }
        }
        
        // Если не удалось найти уникальную тему, возвращаем базовую с предупреждением
        logger.warning("⚠️ Не удалось найти уникальную тему за \(maxAttempts) попыток")
        return generateBaseTopic(for: category)
    }
    
    // MARK: - Private Methods
    
    private func generateBaseTopic(for category: PostCategory) -> String {
        switch category {
        case .lifehack:
            return generateLifehackTopic()
        case .comparison:
            return generateComparisonTopic()
        case .budget:
            return generateBudgetTopic()
        case .trending:
            return generateTrendingTopic()
        case .destination:
            return generateDestinationTopic()
        case .season:
            return generateSeasonalTopic()
        case .weekend:
            return generateWeekendTopic()
        case .mistake:
            return generateMistakeTopic()
        case .hiddenGem:
            return generateHiddenGemTopic()
        case .visaFree:
            return generateVisaFreeTopic()
        }
    }
    
    private func generateLifehackTopic() -> String {
        let baseTopics = [
            "как найти дешёвые билеты",
            "как упаковать чемодан",
            "как выбрать отель",
            "как сэкономить на еде",
            "как избежать толп туристов",
            "как получить бесплатный апгрейд",
            "как пользоваться каршерингом за границей",
            "как найти бесплатные экскурсии",
            "как быстро пройти паспортный контроль",
            "как выбрать место в самолёте"
        ]
        
        let angles = [
            "секрет который экономит",
            "ошибка которая стоит денег",
            "лайфхак от стюардессы",
            "трюк который знают только",
            "способ который работает",
            "хитрость для экономии",
            "приём для быстрого",
            "метод для дешёвого"
        ]
        
        let baseTopic = baseTopics.randomElement() ?? "путешествия"
        let angle = angles.randomElement() ?? "способ"
        
        return "\(angle) \(baseTopic)"
    }
    
    private func generateComparisonTopic() -> String {
        let destinations = [
            "Турция vs Египет", "Дубай vs Оман", "Таиланд vs Вьетнам",
            "Грузия vs Армения", "Португалия vs Испания", "Черногория vs Албания",
            "Мальдивы vs Сейшелы", "Бали vs Филиппины", "Кипр vs Греция"
        ]
        
        let aspects = [
            "где дешевле отдых", "что лучше для семьи", "куда ехать зимой",
            "сравнение цен и сервиса", "плюсы и минусы", "что выбрать в 2025"
        ]
        
        let destination = destinations.randomElement() ?? "два направления"
        let aspect = aspects.randomElement() ?? "сравнение"
        
        return "\(destination): \(aspect)"
    }
    
    private func generateBudgetTopic() -> String {
        let destinations = [
            "Турция", "Египет", "ОАЭ", "Таиланд", "Вьетнам", "Грузия",
            "Армения", "Узбекистан", "Казахстан", "Азербайджан"
        ]
        
        let budgetRanges = [
            "за 30000₽", "за 50000₽", "за 100000₽", "до 40000₽",
            "бюджетно", "недорого", "экономно", "дешёво"
        ]
        
        let destination = destinations.randomElement() ?? "популярное направление"
        let budget = budgetRanges.randomElement() ?? "бюджетно"
        
        return "Отдых в \(destination) \(budget): полный расчёт бюджета"
    }
    
    private func generateTrendingTopic() -> String {
        let _ = Calendar.current.component(.year, from: Date())
        
        let trendingAspects = [
            "куда поехать в 2025",
            "популярные направления 2025",
            "тренды путешествий 2025",
            "хиты сезона 2025",
            "модные направления 2025",
            "куда летят все в 2025"
        ]
        
        return trendingAspects.randomElement() ?? "тренды путешествий"
    }
    
    private func generateDestinationTopic() -> String {
        let destinations = [
            "Турция", "Египет", "ОАЭ", "Таиланд", "Вьетнам", "Грузия",
            "Армения", "Узбекистан", "Казахстан", "Азербайджан",
            "Португалия", "Испания", "Италия", "Кипр", "Греция"
        ]
        
        let aspects = [
            "полный гайд", "что посмотреть", "где остановиться",
            "сколько стоит", "плюсы и минусы", "личный опыт",
            "секретные места", "ошибки туристов", "лайфхаки"
        ]
        
        let destination = destinations.randomElement() ?? "популярная страна"
        let aspect = aspects.randomElement() ?? "обзор"
        
        return "\(destination): \(aspect)"
    }
    
    private func generateSeasonalTopic() -> String {
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        let seasonalTopics: [String]
        switch currentMonth {
        case 12, 1, 2:
            seasonalTopics = [
                "куда поехать зимой", "зимний отдых на море",
                "горнолыжные курорты", "где тепло зимой",
                "новогодние каникулы", "зимовка в тёплых странах"
            ]
        case 3, 4, 5:
            seasonalTopics = [
                "куда поехать весной", "весенние направления",
                "майские праздники", "бархатный сезон",
                "где цветёт сакура", "весенние фестивали"
            ]
        case 6, 7, 8:
            seasonalTopics = [
                "куда поехать летом", "летний отдых на море",
                "пляжные направления", "летние фестивали",
                "где не жарко летом", "горный отдых летом"
            ]
        case 9, 10, 11:
            seasonalTopics = [
                "куда поехать осенью", "осенние направления",
                "бархатный сезон", "осенние краски",
                "где тепло осенью", "осенние фестивали"
            ]
        default:
            seasonalTopics = ["сезонные направления"]
        }
        
        return seasonalTopics.randomElement() ?? "сезонный отдых"
    }
    
    private func generateWeekendTopic() -> String {
        let weekendDestinations = [
            "Санкт-Петербург", "Калининград", "Казань", "Сочи",
            "Крым", "Алтай", "Карелия", "Золотое кольцо"
        ]
        
        let aspects = [
            "выходные в", "куда съездить на выходные",
            "короткая поездка в", "2 дня в",
            "что посмотреть за выходные в"
        ]
        
        let destination = weekendDestinations.randomElement() ?? "близкий город"
        let aspect = aspects.randomElement() ?? "выходные"
        
        return "\(aspect) \(destination)"
    }
    
    private func generateMistakeTopic() -> String {
        let mistakeTypes = [
            "ошибки туристов", "что не стоит делать",
            "главные ошибки", "типичные промахи",
            "ошибки которые стоят денег", "что портит отпуск"
        ]
        
        let contexts = [
            "при бронировании", "в аэропорту", "в отеле",
            "при обмене валюты", "при выборе экскурсий",
            "при упаковке чемодана", "при планировании маршрута"
        ]
        
        let mistakeType = mistakeTypes.randomElement() ?? "ошибки"
        let context = contexts.randomElement() ?? "в путешествии"
        
        return "\(mistakeType) \(context)"
    }
    
    private func generateHiddenGemTopic() -> String {
        let hiddenGems = [
            "скрытые жемчужины", "малоизвестные места",
            "секретные локации", "непопулярные направления",
            "скрытые сокровища", "тайные уголки"
        ]
        
        let regions = [
            "Европы", "Азии", "России", "СНГ", "Средиземноморья",
            "Балкан", "Кавказа", "Средней Азии"
        ]
        
        let gem = hiddenGems.randomElement() ?? "скрытые места"
        let region = regions.randomElement() ?? "мира"
        
        return "\(gem) \(region)"
    }
    
    private func generateVisaFreeTopic() -> String {
        let _ = Calendar.current.component(.year, from: Date())
        
        let visaFreeAspects = [
            "безвизовые страны 2025",
            "куда поехать без визы",
            "страны без визы для россиян",
            "безвизовые направления 2025",
            "куда лететь без визы"
        ]
        
        return visaFreeAspects.randomElement() ?? "безвизовые страны"
    }
    
    private func enhanceWithCurrentTrends(_ topic: String, category: PostCategory) -> String {
        let _ = Calendar.current.component(.year, from: Date())
        
        // Добавляем актуальные тренды 2025
        let trends = [
            "2025", "новые правила", "актуально", "сейчас",
            "в этом году", "обновлено", "свежие данные"
        ]
        
        // Добавляем тренд только в 30% случаев, чтобы не перегружать
        if Int.random(in: 1...10) <= 3 {
            let trend = trends.randomElement() ?? "2025"
            return "\(topic) \(trend)"
        }
        
        return topic
    }
    
    private func addSeasonalElements(_ topic: String, category: PostCategory) -> String {
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        // Добавляем сезонные элементы только для определённых категорий
        guard [.season, .destination, .budget, .trending].contains(category) else {
            return topic
        }
        
        let seasonalElements: [String]
        switch currentMonth {
        case 12, 1, 2:
            seasonalElements = ["зимой", "в холодное время", "для зимовки"]
        case 3, 4, 5:
            seasonalElements = ["весной", "в межсезонье", "для майских"]
        case 6, 7, 8:
            seasonalElements = ["летом", "в сезон", "для отпуска"]
        case 9, 10, 11:
            seasonalElements = ["осенью", "в бархатный сезон", "для осенних каникул"]
        default:
            seasonalElements = []
        }
        
        // Добавляем сезонный элемент в 40% случаев
        if Int.random(in: 1...10) <= 4, let element = seasonalElements.randomElement() {
            return "\(topic) \(element)"
        }
        
        return topic
    }
}
