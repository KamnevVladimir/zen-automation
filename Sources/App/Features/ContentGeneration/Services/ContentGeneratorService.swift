import Vapor
import Fluent

protocol ContentGeneratorServiceProtocol {
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse
}

final class ContentGeneratorService: ContentGeneratorServiceProtocol {
    private let openAIClient: OpenAIClientProtocol
    private let validator: ContentValidatorProtocol
    private let logger: Logger
    
    init(
        openAIClient: OpenAIClientProtocol,
        validator: ContentValidatorProtocol,
        logger: Logger
    ) {
        self.openAIClient = openAIClient
        self.validator = validator
        self.logger = logger
    }
    
    func generatePost(request: GenerationRequest, db: Database) async throws -> GenerationResponse {
        logger.info("🚀 Начинаю генерацию поста: \(request.templateType.rawValue)")
        
        let startTime = Date()
        
        // 1. Генерация текста
        let textContent = try await generateText(for: request)
        logger.info("✅ Текст сгенерирован")
        
        // 2. Парсинг JSON ответа
        guard let contentData = textContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw Abort(.internalServerError, reason: "Не удалось распарсить ответ GPT")
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
        
        let messages: [OpenAIChatRequest.Message] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userPrompt)
        ]
        
        let response = try await openAIClient.chatCompletion(
            messages: messages,
            responseFormat: "json_object"
        )
        
        return response.choices.first?.message.content ?? ""
    }
    
    private func generateImages(prompts: [String]) async throws -> [String] {
        var urls: [String] = []
        
        for prompt in prompts.prefix(3) {
            let url = try await openAIClient.generateImage(prompt: prompt)
            urls.append(url)
        }
        
        return urls
    }
    
    private func estimateCost(textTokens: Int, images: Int) -> Double {
        // GPT-4 Turbo: ~$0.01 per 1K input, ~$0.03 per 1K output
        let textCost = (Double(textTokens) / 1000.0) * 0.02
        
        // DALL-E 3 HD: $0.080 per image
        let imageCost = Double(images) * 0.080
        
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

