import Vapor

extension Logger {
    static func zen() -> Logger {
        var logger = Logger(label: "com.zen-automation")
        logger.logLevel = .info
        return logger
    }
}

