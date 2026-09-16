import Foundation
import os

/// Lightweight category-based logging on top of the unified logging system.
enum Log {
    private static let subsystem = "studio.liberated.speakease"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let enhancement = Logger(subsystem: subsystem, category: "enhancement")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let injection = Logger(subsystem: subsystem, category: "injection")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
}
