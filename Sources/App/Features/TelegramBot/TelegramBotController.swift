import Vapor
import Fluent

/// Контроллер для обработки команд от пользователя через Telegram
final class TelegramBotController {
    let contentGenerator: ContentGeneratorServiceProtocol
    let publisher: ZenPublisherProtocol
    let stateManager = BotStateManager()
    
    init(contentGenerator: ContentGeneratorServiceProtocol, publisher: ZenPublisherProtocol) {
        self.contentGenerator = contentGenerator
        self.publisher = publisher
    }
    
    func handleMessage(text: String, userId: Int, chatId: Int, req: Request) async {
        let currentState = stateManager.getState(for: userId)
        
        switch currentState {
        case .idle:
            await handleIdleState(text: text, userId: userId, chatId: chatId, req: req)
        case .waitingForTopic:
            await handleTopicInput(text: text, userId: userId, chatId: chatId, req: req)
        }
    }
    
    private func handleIdleState(text: String, userId: Int, chatId: Int, req: Request) async {
        if text == "🚀 Создать новый пост" {
            // Переключаем в режим ожидания темы
            stateManager.setState(.waitingForTopic, for: userId)
            
            try? await sendMessage(
                chatId: chatId,
                text: """
                📝 Введите тему для нового поста:
                
                Примеры:
                • Дешевые авиабилеты в ноябре 2025
                • 7 лайфхаков для экономии на отелях
                • Турция vs Египет для отдыха
                • Куда слетать на выходные из Москвы
                
                Просто напишите тему, без дополнительных команд 👇
                """,
                keyboard: getCancelKeyboard(),
                req: req
            )
        } else if text == "🔍 Найти посты для промо" {
            // Поиск постов в Дзене для комментирования
            await findPostsForPromotion(chatId: chatId, req: req)
        } else if text == "/start" {
            await sendWelcomeMessage(chatId: chatId, req: req)
        } else {
            try? await sendMessage(
                chatId: chatId,
                text: "Используйте кнопки ниже 👇",
                keyboard: getMainKeyboard(),
                req: req
            )
        }
    }
    
    private func handleTopicInput(text: String, userId: Int, chatId: Int, req: Request) async {
        if text == "❌ Отмена" {
            // Возвращаемся в обычный режим
            stateManager.resetState(for: userId)
            
            try? await sendMessage(
                chatId: chatId,
                text: "✅ Отменено. Используйте кнопку для создания нового поста.",
                keyboard: getMainKeyboard(),
                req: req
            )
            return
        }
        
        // Обрабатываем введенную тему
        let topic = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !topic.isEmpty else {
            try? await sendMessage(
                chatId: chatId,
                text: "⚠️ Пожалуйста, введите тему для поста.",
                keyboard: getCancelKeyboard(),
                req: req
            )
            return
        }
        
        // Возвращаемся в обычный режим
        stateManager.resetState(for: userId)
        
        // Создаем пост
        await createPost(topic: topic, chatId: chatId, req: req)
    }
    
    private func sendWelcomeMessage(chatId: Int, req: Request) async {
        let message = """
        🤖 **Добро пожаловать в Zen Automation Bot!**
        
        Я помогу вам:
        
        🚀 **Создавать посты** для Яндекс Дзен про путешествия
        🔍 **Находить посты** для промо-активности с готовыми ответами
        
        📱 **Канал публикации:** \(AppConfig.telegramChannelId)
        ⚡ **Автопосты:** 08:00, 12:00, 16:00, 20:00 MSK
        
        **Возможности:**
        • Генерация вирусных постов с AI
        • Создание коротких постов для Telegram
        • Полные статьи на Telegraph
        • Готовые ответы на вопросы в Дзене
        
        Используйте кнопки ниже 👇
        """
        
        try? await sendMessage(
            chatId: chatId,
            text: message,
            keyboard: getMainKeyboard(),
            req: req
        )
    }
    
    private func findPostsForPromotion(chatId: Int, req: Request) async {
        do {
            req.logger.info("🔍 Ищу посты в Дзене и анализирую наши статьи")
            
            try await sendMessage(
                chatId: chatId,
                text: """
                🔍 Ищу подходящие посты в Яндекс Дзене...
                📚 Анализирую наши статьи для умных ответов...
                
                ⏳ Это займёт 15-20 секунд...
                """,
                keyboard: getMainKeyboard(),
                req: req
            )
            
            // Создаём SmartPromoService
            let aiClient = AnthropicClient(client: req.client, logger: req.logger)
            let promoService = SmartPromoService(
                client: req.client,
                logger: req.logger,
                aiClient: aiClient
            )
            
            // Находим посты с умными ответами на основе НАШИХ статей
            let suggestions = try await promoService.findPostsWithSmartResponses(db: req.db)
            
            guard !suggestions.isEmpty else {
                try await sendMessage(
                    chatId: chatId,
                    text: "⚠️ Не удалось найти подходящие посты. Попробуйте позже.",
                    keyboard: getMainKeyboard(),
                    req: req
                )
                return
            }
            
            var responseText = "🎯 **Найдено \(suggestions.count) поста в Яндекс Дзене**\n\n"
            responseText += "📋 **Готовые комментарии для продвижения нашего канала:**\n\n"
            
            for (index, suggestion) in suggestions.enumerated() {
                responseText += """
                **\(index + 1). Пост:** \(suggestion.postTitle)
                🔗 **Ссылка:** \(suggestion.postUrl)
                
                ❓ **Вопрос:**
                "\(suggestion.question)"
                
                💬 **Твой готовый ответ (скопируй):**
                \(suggestion.suggestedResponse)
                
                """
                
                responseText += "――――――――――――――――――\n\n"
            }
            
            responseText += """
            ✅ **Как использовать:**
            1. Открой ссылку на пост в Яндекс Дзене
            2. Найди этот вопрос в комментариях
            3. Скопируй готовый ответ выше
            4. Вставь и отправь комментарий
            
            🎯 **Важно:**
            • В ответах есть ссылки на НАШ канал в Дзене
            • Это привлечёт новых подписчиков
            • 3-5 комментариев в день = +10-20 подписчиков в неделю!
            
            💡 **Совет:** Отвечай на свежие вопросы (<24ч) - больше шансов что увидят!
            """
            
            try await sendMessage(
                chatId: chatId,
                text: responseText,
                keyboard: getMainKeyboard(),
                req: req
            )
            
        } catch {
            req.logger.error("❌ Ошибка поиска постов: \(error)")
            
            try? await sendMessage(
                chatId: chatId,
                text: """
                ❌ Ошибка: \(error.localizedDescription)
                
                Попробуйте ещё раз позже 👇
                """,
                keyboard: getMainKeyboard(),
                req: req
            )
        }
    }
    
    private func createPost(topic: String, chatId: Int, req: Request) async {
        do {
            req.logger.info("🚀 Создаю пост на тему: \(topic)")
            
            // Отправляем уведомление что начали генерацию
            try await sendMessage(
                chatId: chatId,
                text: """
                🚀 Сейчас создам новый пост на тему "\(topic)"
                
                ⏳ Это займёт 1-2 минуты...
                """,
                keyboard: getMainKeyboard(),
                req: req
            )
            
            // Определяем тип поста на основе темы
            let templateType = determinePostType(from: topic)
            
            // Создаём запрос на генерацию
            let request = GenerationRequest(
                templateType: templateType,
                topic: topic,
                destinations: extractDestinations(from: topic),
                priceData: nil,
                trendData: nil
            )
            
            // Генерируем пост
            let response = try await contentGenerator.generatePost(
                request: request,
                db: req.db
            )
            
            req.logger.info("✅ Пост сгенерирован: \(response.postId)")
            
            // Публикуем пост
            guard let post = try await ZenPostModel.find(response.postId, on: req.db) else {
                throw Abort(.notFound, reason: "Post not found")
            }
            
            let publishResult = try await publisher.publish(post: post, db: req.db)
            
            if publishResult.success {
                try await sendMessage(
                    chatId: chatId,
                    text: """
                    ✅ Пост успешно создан и опубликован!
                    
                    📝 **\(response.title)**
                    
                    📊 Символов:
                    • Короткий: \(response.shortPost.count)
                    • Полный: \(response.fullPost.count)
                    🖼 Изображений: \(response.imageURLs.count)
                    📱 Канал: \(AppConfig.telegramChannelId)
                    
                    🔄 Дзен импортирует пост в течение 30 минут
                    
                    Хотите создать ещё один пост? 👇
                    """,
                    keyboard: getMainKeyboard(),
                    req: req
                )
            } else {
                try await sendMessage(
                    chatId: chatId,
                    text: """
                    ❌ Ошибка публикации: \(publishResult.errorMessage ?? "Unknown error")
                    
                    Попробуйте ещё раз 👇
                    """,
                    keyboard: getMainKeyboard(),
                    req: req
                )
            }
            
        } catch {
            req.logger.error("❌ Ошибка создания поста: \(error)")
            
            try? await sendMessage(
                chatId: chatId,
                text: """
                ❌ Ошибка при создании поста: \(error.localizedDescription)
                
                Попробуйте ещё раз 👇
                """,
                keyboard: getMainKeyboard(),
                req: req
            )
        }
    }
    
    // MARK: - Keyboards
    
    private func getMainKeyboard() -> TelegramKeyboard {
        return TelegramKeyboard(
            keyboard: [
                [TelegramKeyboardButton(text: "🚀 Создать новый пост")],
                [TelegramKeyboardButton(text: "🔍 Найти посты для промо")]
            ],
            resizeKeyboard: true,
            persistent: true
        )
    }
    
    private func getCancelKeyboard() -> TelegramKeyboard {
        return TelegramKeyboard(
            keyboard: [
                [TelegramKeyboardButton(text: "❌ Отмена")]
            ],
            resizeKeyboard: true,
            persistent: false
        )
    }
    
    private func determinePostType(from topic: String) -> PostCategory {
        let lowercased = topic.lowercased()
        
        if lowercased.contains("лайфхак") || lowercased.contains("секрет") || lowercased.contains("совет") {
            return .lifehack
        } else if lowercased.contains("бюджет") || lowercased.contains("дешев") || lowercased.contains("экономи") {
            return .budget
        } else if lowercased.contains("сравнен") || lowercased.contains(" vs ") || lowercased.contains("или") {
            return .comparison
        } else if lowercased.contains("выходн") || lowercased.contains("weekend") {
            return .weekend
        } else if lowercased.contains("ошибк") || lowercased.contains("не дела") {
            return .mistake
        } else {
            return .destination
        }
    }
    
    private func extractDestinations(from topic: String) -> [String]? {
        // Простое извлечение стран/городов (можно улучшить)
        let destinations = ["Турция", "Египет", "ОАЭ", "Таиланд", "Грузия", "Армения", "Вьетнам", "Индия", "Китай", "Узбекистан"]
        
        let foundDestinations = destinations.filter { destination in
            topic.lowercased().contains(destination.lowercased())
        }
        
        return foundDestinations.isEmpty ? nil : foundDestinations
    }
    
    
    private func sendMessage(
        chatId: Int, 
        text: String, 
        keyboard: TelegramKeyboard? = nil, 
        req: Request
    ) async throws {
        let url = URI(string: "https://api.telegram.org/bot\(AppConfig.telegramToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        var body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "Markdown"
        ]
        
        if let keyboard = keyboard {
            let keyboardData = try JSONEncoder().encode(keyboard)
            let keyboardDict = try JSONSerialization.jsonObject(with: keyboardData)
            body["reply_markup"] = keyboardDict
        }
        
        let data = try JSONSerialization.data(withJSONObject: body)
        request.body = .init(data: data)
        
        _ = try await req.client.send(request)
    }
}

// MARK: - Telegram Models

struct TelegramUpdate: Content {
    let updateId: Int
    let message: TelegramMessage?
    
    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

struct TelegramMessage: Content {
    let messageId: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from
        case chat
        case text
    }
}

struct TelegramUser: Content {
    let id: Int
    let isBot: Bool
    let firstName: String
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case username
    }
}

struct TelegramChat: Content {
    let id: Int
    let type: String
}

// MARK: - Keyboard Models

struct TelegramKeyboard: Content {
    let keyboard: [[TelegramKeyboardButton]]
    let resizeKeyboard: Bool
    let persistent: Bool
    
    enum CodingKeys: String, CodingKey {
        case keyboard
        case resizeKeyboard = "resize_keyboard"
        case persistent = "is_persistent"
    }
}

struct TelegramKeyboardButton: Content {
    let text: String
}
