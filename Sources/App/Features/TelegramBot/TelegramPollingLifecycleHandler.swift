import Vapor

/// Lifecycle handler для запуска Telegram polling
struct TelegramPollingLifecycleHandler: LifecycleHandler {
    let pollingService: TelegramPollingService
    
    func didBoot(_ application: Application) throws {
        pollingService.start()
        application.logger.info("🤖 Telegram Polling запущен")
    }
    
    func shutdown(_ application: Application) {
        pollingService.stop()
        application.logger.info("🛑 Telegram Polling остановлен")
    }
}
