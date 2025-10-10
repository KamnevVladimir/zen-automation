import Foundation

/// Состояния бота для каждого пользователя
enum BotState: String, Codable {
    case idle = "idle"
    case waitingForTopic = "waiting_for_topic"
}

/// Менеджер состояний бота (в памяти, для простоты)
final class BotStateManager {
    private var userStates: [Int: BotState] = [:]
    
    func setState(_ state: BotState, for userId: Int) {
        userStates[userId] = state
    }
    
    func getState(for userId: Int) -> BotState {
        return userStates[userId] ?? .idle
    }
    
    func resetState(for userId: Int) {
        userStates[userId] = .idle
    }
}
