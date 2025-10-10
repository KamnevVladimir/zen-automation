import Vapor
import Fluent

/// Контроллер для обработки команд от пользователя через Telegram
final class TelegramBotController {
    let contentGenerator: ContentGeneratorServiceProtocol
    let publisher: ZenPublisherProtocol
    
    init(contentGenerator: ContentGeneratorServiceProtocol, publisher: ZenPublisherProtocol) {
        self.contentGenerator = contentGenerator
        self.publisher = publisher
    }
    
    func handleCreatePostCommand(text: String, chatId: Int, req: Request) async {
        do {
            // Извлекаем тему из сообщения
            let topic = extractTopic(from: text)
            
            req.logger.info("🚀 Создаю пост на тему: \(topic)")
            
            // Отправляем уведомление что начали генерацию
            try await sendMessage(
                chatId: chatId,
                text: "🚀 Начинаю создавать пост на тему: \"\(topic)\"\n\nЭто займёт 1-2 минуты...",
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
                    
                    📝 Заголовок: \(response.title)
                    📊 Символов: \(response.body.count)
                    🖼 Изображений: \(response.imageURLs.count)
                    📱 Канал: \(AppConfig.telegramChannelId)
                    
                    Дзен импортирует пост в течение 30 минут.
                    """,
                    req: req
                )
            } else {
                try await sendMessage(
                    chatId: chatId,
                    text: "❌ Ошибка публикации: \(publishResult.errorMessage ?? "Unknown error")",
                    req: req
                )
            }
            
        } catch {
            req.logger.error("❌ Ошибка создания поста: \(error)")
            
            try? await sendMessage(
                chatId: chatId,
                text: "❌ Ошибка при создании поста: \(error.localizedDescription)",
                req: req
            )
        }
    }
    
    private func extractTopic(from text: String) -> String {
        // Извлекаем тему из "Сделай пост на тематику <тема>"
        let pattern = "сделай пост на тематику[\\s<]*([^>]+)[>]*"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex.firstMatch(in: text, range: range),
           let topicRange = Range(match.range(at: 1), in: text) {
            return String(text[topicRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Если не смогли извлечь, возвращаем весь текст после "тематику"
        if let index = text.lowercased().range(of: "тематику")?.upperBound {
            return String(text[index...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
        }
        
        return "путешествия"
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
    
    
    private func sendMessage(chatId: Int, text: String, req: Request) async throws {
        let url = URI(string: "https://api.telegram.org/bot\(AppConfig.telegramToken)/sendMessage")
        
        var request = ClientRequest(method: .POST, url: url)
        request.headers.add(name: .contentType, value: "application/json")
        
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ]
        
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
