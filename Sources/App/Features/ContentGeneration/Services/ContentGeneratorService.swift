import Vapor
import Fluent

protocol ContentGeneratorServiceProtocol {
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse
}

final class ContentGeneratorService: ContentGeneratorServiceProtocol {
    private let aiClient: AIClientProtocol
    private let validator: ContentValidatorProtocol
    private let logger: Logger
    
    init(
        aiClient: AIClientProtocol,
        validator: ContentValidatorProtocol,
        logger: Logger
    ) {
        self.aiClient = aiClient
        self.validator = validator
        self.logger = logger
    }
    
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse {
        logger.info("🚀 Начинаю генерацию поста: \(request.templateType.rawValue)")
        
        let startTime = Date()
        
        // 1. Генерация текста
        let textContent = try await generateText(for: request)
        logger.info("✅ Текст сгенерирован")
        
        // 2. Парсинг JSON ответа от Claude
        guard let contentData = textContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw Abort(.internalServerError, reason: "Не удалось распарсить ответ Claude")
        }
        
        let title = json["title"] as? String ?? "Без названия"
        let subtitle = json["subtitle"] as? String
        let body = json["body"] as? String ?? ""
        let tags = json["tags"] as? [String] ?? []
        let metaDescription = json["meta_description"] as? String
        let imagePrompts = json["image_prompts"] as? [String] ?? []
        let estimatedReadTime = json["estimated_read_time"] as? Int ?? 5
        
        // 3. Валидация контента
        let validationResult = validator.validate(body: body, tags: tags)
        if !validationResult.isValid {
            logger.warning("⚠️ Контент не прошёл валидацию: \(validationResult.issues.joined(separator: ", "))")
            throw Abort(.badRequest, reason: "Контент не прошёл валидацию")
        }
        logger.info("✅ Контент валиден (score: \(validationResult.score))")
        
        // 4. Генерация изображений
        let imageURLs = try await generateImages(prompts: imagePrompts)
        logger.info("✅ Изображения сгенерированы: \(imageURLs.count) шт")
        
        // 5. Сохранение в БД
        let post = ZenPostModel(
            title: title,
            subtitle: subtitle,
            body: body,
            tags: tags,
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
                prompt: imagePrompts[safe: index] ?? "",
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
            body: body,
            tags: tags,
            metaDescription: metaDescription,
            imageURLs: imageURLs,
            estimatedReadTime: estimatedReadTime,
            status: "draft"
        )
    }
    
    private func generateText(for request: GenerationRequest) async throws -> String {
        let systemPrompt = ContentPrompt.buildSystemPrompt()
        let userPrompt = ContentPrompt.buildUserPrompt(for: request)
        
        return try await aiClient.generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
    }
    
    private func generateImages(prompts: [String]) async throws -> [String] {
        var urls: [String] = []
        
        for prompt in prompts.prefix(3) {
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

