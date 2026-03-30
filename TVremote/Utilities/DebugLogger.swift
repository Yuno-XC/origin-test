import Foundation

/// Centralized debug logging utility for the TVremote app
final class DebugLogger {
    enum Category: String {
        case adapter = "[AndroidTVAdapter]"
        case discovery = "[DeviceDiscovery]"
        case persistence = "[Persistence]"
        case viewModel = "[ViewModel]"
        case pairing = "[Pairing]"
        case remote = "[Remote]"
        case general = "[TVremote]"
    }

    /// Whether debug logging is enabled (can be controlled via environment variable)
    private static let isEnabled: Bool = {
        #if DEBUG
        // Check environment variable DEBUG_TVREMOTE
        return ProcessInfo.processInfo.environment["DEBUG_TVREMOTE"] != "0"
        #else
        return false
        #endif
    }()

    /// Log a debug message with emoji for visual distinction
    static func log(_ category: Category, _ message: String, emoji: String = "ℹ️") {
        guard isEnabled else { return }
        print("\(emoji) \(category.rawValue) \(message)")
    }

    /// Log connection-related messages
    static func logConnection(_ category: Category, _ message: String) {
        log(category, message, emoji: "🔌")
    }

    /// Log success messages
    static func logSuccess(_ category: Category, _ message: String) {
        log(category, message, emoji: "✅")
    }

    /// Log error messages
    static func logError(_ category: Category, _ message: String) {
        log(category, message, emoji: "❌")
    }

    /// Log warning messages
    static func logWarning(_ category: Category, _ message: String) {
        log(category, message, emoji: "⚠️")
    }

    /// Log state transitions
    static func logState(_ category: Category, _ message: String) {
        log(category, message, emoji: "🔄")
    }

    /// Log sent data
    static func logSend(_ category: Category, _ message: String) {
        log(category, message, emoji: "📤")
    }

    /// Log received data
    static func logReceived(_ category: Category, _ message: String) {
        log(category, message, emoji: "📥")
    }

    /// Log mapping information
    static func logMapping(_ category: Category, _ message: String) {
        log(category, message, emoji: "🗺️")
    }
}
