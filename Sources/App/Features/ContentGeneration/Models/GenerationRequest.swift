import Vapor

struct GenerationRequest: Content {
    let templateType: PostCategory
    let topic: String?
    let destinations: [String]?
    let priceData: [PriceInfo]?
    let trendData: TrendInfo?
    
    struct PriceInfo: Content {
        let destination: String
        let price: Int
        let currency: String
        let date: String
    }
    
    struct TrendInfo: Content {
        let popularDestinations: [String]
        let searchVolume: Int
    }
}

struct GenerationResponse: Content {
    let postId: UUID
    let title: String
    let subtitle: String?
    let body: String
    let tags: [String]
    let metaDescription: String?
    let imageURLs: [String]
    let estimatedReadTime: Int
    let status: String
}

struct ContentPrompt {
    let systemPrompt: String
    let userPrompt: String
    let imagePrompts: [String]
    
    static func buildSystemPrompt() -> String {
        """
        Ты — эксперт по контент-маркетингу и путешествиям. Твоя задача — писать 
        увлекательные, информативные статьи для Яндекс Дзен про дешёвые путешествия.

        ПРАВИЛА:
        1. Стиль: дружелюбный, но профессиональный. Как будто пишешь другу.
        2. Структура: чёткая, с подзаголовками и списками.
        3. Факты: только проверенные данные. Цены должны быть актуальными.
        4. Уникальность: не копируй из интернета. Создавай оригинальный контент.
        5. Интеграция бота: естественная, 1-2 раза в статье, в контексте.
        6. Длина: 3000-7000 символов в зависимости от типа поста.
        7. Эмодзи: используй умеренно (2-3 на абзац), для визуального разделения.
        8. Призыв к действию: в конце статьи, мотивируй читателя.

        ЗАПРЕЩЕНО:
        - Кликбейт без содержания
        - Ложная информация
        - Плагиат
        - Агрессивная реклама бота
        - Орфографические ошибки
        - Слишком длинные абзацы (макс. 5-7 строк)

        ФОРМАТ ОТВЕТА: JSON
        {
          "title": "Заголовок статьи (до 100 символов)",
          "subtitle": "Подзаголовок (до 200 символов, опционально)",
          "body": "Текст статьи (с разметкой для Дзен)",
          "tags": ["тег1", "тег2", "тег3", "тег4", "тег5"],
          "meta_description": "SEO-описание (до 160 символов)",
          "bot_integration_points": ["строка 1", "строка 2"],
          "image_prompts": [
            "Промпт для главной картинки",
            "Промпт для картинки 2"
          ],
          "estimated_read_time": 5,
          "target_audience": "budget_travelers"
        }
        """
    }
    
    static func buildUserPrompt(for request: GenerationRequest) -> String {
        switch request.templateType {
        case .destination:
            return buildDestinationPrompt(request)
        case .lifehack:
            return buildLifehackPrompt(request)
        case .comparison:
            return buildComparisonPrompt(request)
        case .budget:
            return buildBudgetPrompt(request)
        case .trending:
            return buildTrendingPrompt(request)
        default:
            return buildGenericPrompt(request)
        }
    }
    
    private static func buildDestinationPrompt(_ request: GenerationRequest) -> String {
        let destination = request.destinations?.first ?? "Таиланд"
        let price = request.priceData?.first?.price ?? 30000
        
        return """
        Создай статью типа "Destination Post" по следующим данным:
        
        ТЕМА: Куда полететь в текущем месяце
        СТРАНА: \(destination)
        
        АКТУАЛЬНЫЕ ДАННЫЕ:
        - Цена билета: \(price)₽
        - Популярность: высокая
        
        ТРЕБОВАНИЯ:
        - Объём: 5000-6000 символов
        - Фокус: пляжный отдых + культура
        - Интеграция бота @\(AppConfig.botUsername): в разделе про цены и в конце
        - Целевая аудитория: семьи и пары
        
        ДОПОЛНИТЕЛЬНО:
        - Добавь раздел "Что взять с собой"
        - Упомяни актуальные визовые правила
        - Добавь совет про мониторинг цен через бота
        """
    }
    
    private static func buildLifehackPrompt(_ request: GenerationRequest) -> String {
        """
        Создай статью типа "Lifehack Post":
        
        ТЕМА: Секреты дешёвых авиабилетов
        
        ТРЕБОВАНИЯ:
        - Объём: 3000-4000 символов
        - 5-7 практичных лайфхаков
        - Интеграция бота @\(AppConfig.botUsername): в бонус-лайфхаке
        - Конкретные примеры экономии
        
        Заголовок должен включать число (например: "7 секретов...")
        """
    }
    
    private static func buildComparisonPrompt(_ request: GenerationRequest) -> String {
        let destinations = request.destinations ?? ["Турция", "Египет"]
        let country1 = destinations.first ?? "Турция"
        let country2 = destinations.dropFirst().first ?? "Египет"
        
        return """
        Создай статью типа "Comparison Post":
        
        СРАВНЕНИЕ: \(country1) vs \(country2)
        
        СТРУКТУРА:
        - Сравнение цен (таблица)
        - Сравнение погоды
        - Сравнение достопримечательностей
        - Сравнение кухни
        - Вердикт
        
        ТРЕБОВАНИЯ:
        - Объём: 4000-5000 символов
        - Интеграция бота @\(AppConfig.botUsername): в разделе про цены
        - Объективное сравнение
        """
    }
    
    private static func buildBudgetPrompt(_ request: GenerationRequest) -> String {
        """
        Создай статью типа "Budget Post":
        
        ТЕМА: Отпуск за 50,000₽
        
        ТРЕБОВАНИЯ:
        - Объём: 3500-4500 символов
        - 5-7 стран с разбивкой бюджета
        - Интеграция бота @\(AppConfig.botUsername): для мониторинга цен
        - Реалистичные цены
        """
    }
    
    private static func buildTrendingPrompt(_ request: GenerationRequest) -> String {
        let destinations = request.trendData?.popularDestinations ?? ["Турция", "ОАЭ", "Таиланд"]
        
        return """
        Создай статью типа "Trending Post":
        
        ТЕМА: Топ направлений недели
        ПОПУЛЯРНЫЕ НАПРАВЛЕНИЯ: \(destinations.joined(separator: ", "))
        
        ТРЕБОВАНИЯ:
        - Объём: 3000-4000 символов
        - Почему популярны сейчас
        - Актуальные цены
        - Интеграция бота @\(AppConfig.botUsername): как узнавать о трендах
        """
    }
    
    private static func buildGenericPrompt(_ request: GenerationRequest) -> String {
        """
        Создай интересную статью про дешёвые путешествия.
        
        Тема: \(request.topic ?? "путешествия")
        
        ТРЕБОВАНИЯ:
        - Объём: 3000-5000 символов
        - Полезная информация
        - Интеграция бота @\(AppConfig.botUsername)
        """
    }
    
    static func buildImagePrompt(for title: String, position: Int) -> String {
        let basePrompt = """
        Create a professional, high-quality travel photography style image.
        
        STYLE: Bright, vibrant, inviting, professional travel magazine aesthetic
        LIGHTING: Natural, golden hour or soft daylight
        COMPOSITION: Rule of thirds, balanced, no text overlays
        COLORS: Warm and welcoming tones
        MOOD: Inspiring, wanderlust-inducing
        QUALITY: Ultra high-resolution, sharp focus
        
        AVOID: Text, watermarks, people's faces in close-up, logos, dates
        
        Aspect ratio: 16:9
        """
        
        if position == 0 {
            return """
            \(basePrompt)
            
            SUBJECT: Hero image for travel article titled "\(title)"
            Create a stunning aerial or wide-angle view that captures the essence of the destination.
            """
        } else {
            return """
            \(basePrompt)
            
            SUBJECT: Supporting image for travel article titled "\(title)"
            Show specific landmarks, local culture, or scenic views.
            """
        }
    }
}

