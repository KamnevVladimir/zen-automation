import Vapor
import Fluent

protocol ContentGeneratorServiceProtocol {
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse
    func regenerateShortPost(
        fullPost: String,
        currentShortPost: String,
        targetLength: Int
    ) async throws -> String
}

final class ContentGeneratorService: ContentGeneratorServiceProtocol {
    private let aiClient: AIClientProtocol
    private let validator: ContentValidatorProtocol
    private let viralOptimizer: ViralContentOptimizer
    private let logger: Logger
    
    init(
        aiClient: AIClientProtocol,
        validator: ContentValidatorProtocol,
        logger: Logger
    ) {
        self.aiClient = aiClient
        self.validator = validator
        self.viralOptimizer = ViralContentOptimizer()
        self.logger = logger
    }
    
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse {
        logger.info("🚀 Начинаю генерацию поста: \(request.templateType.rawValue)")
        
        let startTime = Date()
        
        // 1. Получаем существующие заголовки для проверки уникальности
        let existingTitles = try await ZenPostModel.query(on: db)
            .all()
            .map { $0.title.lowercased() }
        
        logger.info("📚 Найдено существующих постов: \(existingTitles.count)")
        
        // 2. Генерация текста с контекстом уникальности
        let textContent = try await generateText(for: request, existingTitles: existingTitles)
        logger.info("✅ Текст сгенерирован")
        
        // 2. Парсинг JSON ответа от Claude (убираем markdown code fence если есть)
        var cleanedContent = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Убираем ```json ... ``` если Claude обернул в markdown
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let contentData = cleanedContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            logger.error("❌ Не удалось распарсить JSON. Очищенный контент: \(cleanedContent.prefix(500))")
            throw Abort(.internalServerError, reason: "Не удалось распарсить ответ Claude")
        }
        
        logger.info("✅ JSON успешно распарсен")
        
        let title = json["title"] as? String ?? "Без названия"
        let subtitle = json["subtitle"] as? String
        let body = json["body"] as? String ?? "" // Старое поле, оставлено для совместимости
        let metaDescription = json["meta_description"] as? String
        let imagePromptsEnglish = json["image_prompts_english"] as? [String] ?? []
        let estimatedReadTime = json["estimated_read_time"] as? Int ?? 5
        
        // Парсим два поста из нового формата
        var shortPost = json["short_post"] as? String ?? body
        let fullPost = json["full_post"] as? String ?? body
        
        // Валидируем длину short_post с учётом ссылок
        let botLinkLength = "🤖 [@gdeVacationBot](https://t.me/gdeVacationBot) - поиск дешёвых билетов".count
        let telegraphLinkLength = "📖 [Читать полную статью с деталями](https://telegra.ph/example)".count
        let maxShortPostLength = 1024 - botLinkLength - telegraphLinkLength - 10 // 10 символов для переносов
        
        if shortPost.count > maxShortPostLength {
            logger.warning("⚠️ short_post слишком длинный: \(shortPost.count) > \(maxShortPostLength) символов")
            logger.info("🔄 Просим Claude сократить short_post...")
            
            // Просим Claude сократить short_post
            shortPost = try await requestShorterPost(
                originalShortPost: shortPost,
                maxLength: maxShortPostLength,
                title: title
            )
            
            logger.info("✅ short_post сокращён до \(shortPost.count) символов")
        }
        
        logger.info("📸 Получены английские промпты для изображений: \(imagePromptsEnglish.count) шт")
        
        // Анализируем вирусный потенциал заголовка
        let viralScore = viralOptimizer.analyzeTitle(title)
        logger.info("📊 Вирусность заголовка: \(String(format: "%.1f%%", viralScore.overall * 100))")
        
        if !viralScore.recommendations.isEmpty {
            logger.warning("💡 Рекомендации по улучшению:")
            viralScore.recommendations.forEach { logger.warning("  - \($0)") }
        }
        
        // Оптимизируем теги для Дзена
        let optimizedTags = viralOptimizer.optimizeTags(
            for: request.topic ?? title,
            category: request.templateType
        )
        
        // 3. Валидация контента - ВАЖНО: валидируем fullPost, а не старое поле body!
        let validationResult = validator.validate(body: fullPost, tags: optimizedTags)
        if !validationResult.isValid {
            logger.warning("⚠️ Контент не прошёл валидацию: \(validationResult.issues.joined(separator: ", "))")
            throw Abort(.badRequest, reason: "Контент не прошёл валидацию")
        }
        logger.info("✅ Контент валиден (score: \(validationResult.score))")
        
        // 4. Генерация изображений (используем промпты от Claude на английском)
        logger.info("🎨 Генерирую изображения по промптам от Claude (на английском)")
        let imageURLs = try await generateImages(prompts: imagePromptsEnglish)
        logger.info("✅ Изображения сгенерированы: \(imageURLs.count) шт")
        
        // 5. Сохранение в БД с оптимизированными тегами
        let post = ZenPostModel(
            title: title,
            subtitle: subtitle,
            body: body,
            shortPost: shortPost,
            fullPost: fullPost,
            tags: optimizedTags, // Используем оптимизированные теги
            metaDescription: metaDescription,
            templateType: request.templateType.rawValue,
            status: .draft
        )
        
        try await post.save(on: db)
        
        // 6. Сохранение изображений
        for (index, imageURL) in imageURLs.enumerated() {
            let image = ZenImageModel(
                postId: post.id!,
                url: imageURL,
                prompt: imagePromptsEnglish[safe: index] ?? "",
                position: index
            )
            try await image.save(on: db)
        }
        
        // 7. Логирование
        let duration = Date().timeIntervalSince(startTime)
        logger.info("✅ Пост создан за \(String(format: "%.2f", duration))с")
        
        let log = GenerationLogModel(
            postId: post.id!,
            step: "generation",
            status: "success",
            durationMs: Int(duration * 1000),
            costUsd: estimateCost(textTokens: 9000, images: imageURLs.count)
        )
        try await log.save(on: db)
        
        return GenerationResponse(
            postId: post.id!,
            title: title,
            subtitle: subtitle,
            shortPost: shortPost,
            fullPost: fullPost,
            tags: optimizedTags, // Возвращаем оптимизированные теги
            metaDescription: metaDescription,
            imageURLs: imageURLs,
            estimatedReadTime: estimatedReadTime,
            status: "draft"
        )
    }
    
    /// Просит Claude сократить short_post до нужной длины
    private func requestShorterPost(
        originalShortPost: String,
        maxLength: Int,
        title: String
    ) async throws -> String {
        let shorterPrompt = """
        Сократи этот короткий пост для Telegram до \(maxLength) символов максимум.
        Сохрани основную суть и крючок, но убери лишние детали.
        
        Заголовок: \(title)
        
        Текущий пост (\(originalShortPost.count) символов):
        \(originalShortPost)
        
        Верни ТОЛЬКО сокращённый текст без дополнительных комментариев.
        """
        
        let response = try await aiClient.generateText(
            systemPrompt: "Ты помощник по сокращению текстов. Сокращай чётко и по делу.",
            userPrompt: shorterPrompt
        )
        
        return response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    private func generateText(for request: GenerationRequest, existingTitles: [String]) async throws -> String {
        // Используем вирусные промпты для максимального engagement
        let systemPrompt = ViralPromptBuilder.buildEnhancedSystemPrompt()
        let userPrompt = ViralPromptBuilder.buildViralUserPrompt(
            for: request,
            optimizer: viralOptimizer,
            existingTitles: existingTitles
        )
        
        logger.info("🔥 Генерирую вирусный контент с оптимизацией")
        
        return try await aiClient.generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
    }
    
    private func generateImages(prompts: [String]) async throws -> [String] {
        var urls: [String] = []
        
        // Генерируем только 1 изображение (первое из промптов)
        for prompt in prompts.prefix(1) {
            do {
                let url = try await aiClient.generateImage(prompt: prompt)
                urls.append(url)
            } catch {
                logger.warning("⚠️ Не удалось сгенерировать изображение: \(error)")
                // Используем placeholder если генерация не удалась
                urls.append("https://via.placeholder.com/1792x1024?text=Travel+Image")
            }
        }
        
        return urls
    }
    
    private func estimateCost(textTokens: Int, images: Int) -> Double {
        // Claude Sonnet 4.5: ~$3.00 per 1M input, ~$15.00 per 1M output
        let textCost = (Double(textTokens) / 1_000_000.0) * 9.0 // average
        
        // Stability AI Core: ~$0.03 per image
        let imageCost = Double(images) * 0.03
        
        return textCost + imageCost
    }
    
    /// Пересоздаёт короткий пост с заданной длиной через Claude
    func regenerateShortPost(
        fullPost: String,
        currentShortPost: String,
        targetLength: Int
    ) async throws -> String {
        logger.info("🔄 Пересоздаю короткий пост (цель: \(targetLength) символов, текущий: \(currentShortPost.count))")
        
        let systemPrompt = """
        Ты — эксперт по созданию коротких вирусных постов для Telegram и Яндекс Дзен.
        
        КРИТИЧЕСКИ ВАЖНО: МАКСИМУМ \(targetLength) СИМВОЛОВ!
        
        Твоя задача: сократить длинный пост до \(targetLength) символов, сохранив:
        - Первое предложение (до точки) как заголовок для Дзена (макс 140 символов)
        - Ключевую информацию и ценность
        - Вирусность и призыв к действию
        - Эмодзи (не больше 3-4)
        
        СТРОГИЕ ПРАВИЛА:
        - МАКСИМУМ \(targetLength) символов (считай каждый символ!)
        - Лучше короче, чем длиннее
        - Текст должен быть самодостаточным
        - Без обрезки слов и предложений
        - Убирай лишние детали, оставляй только главное
        """
        
        let userPrompt = """
        ПОЛНЫЙ ПОСТ (\(fullPost.count) символов):
        \(fullPost)
        
        ТЕКУЩИЙ КОРОТКИЙ ПОСТ (\(currentShortPost.count) символов):
        \(currentShortPost)
        
        Создай новую версию короткого поста длиной до \(targetLength) символов.
        Верни только текст поста, без JSON и дополнительных комментариев.
        """
        
        let response = try await aiClient.generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
        
        // Очищаем от возможных markdown блоков
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.info("✅ Короткий пост пересоздан: \(cleanedResponse.count) символов")
        
        return cleanedResponse
    }
}

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Generation Log Model

final class GenerationLogModel: Model, Content {
    static let schema = "generation_logs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: ZenPostModel
    
    @Field(key: "step")
    var step: String
    
    @Field(key: "status")
    var status: String
    
    @OptionalField(key: "error_message")
    var errorMessage: String?
    
    @OptionalField(key: "duration_ms")
    var durationMs: Int?
    
    @OptionalField(key: "cost_usd")
    var costUsd: Double?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        postId: UUID,
        step: String,
        status: String,
        errorMessage: String? = nil,
        durationMs: Int? = nil,
        costUsd: Double? = nil
    ) {
        self.id = id
        self.$post.id = postId
        self.step = step
        self.status = status
        self.errorMessage = errorMessage
        self.durationMs = durationMs
        self.costUsd = costUsd
    }
}

