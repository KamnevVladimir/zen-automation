import Vapor

/// Lifecycle handler для запуска Telegram polling
struct TelegramPollingLifecycleHandler: LifecycleHandler {
    let pollingService: TelegramPollingService
    
    func didBoot(_ application: Application) throws {
        // Запускаем polling с небольшой задержкой после полной инициализации
        application.eventLoopGroup.next().scheduleTask(in: .seconds(2)) {
            self.pollingService.start()
            application.logger.info("🤖 Telegram Polling запущен с задержкой")
        }
    }
    
    func shutdown(_ application: Application) {
        pollingService.stop()
        application.logger.info("🛑 Telegram Polling остановлен")
    }
}
