// DiagnosticsLog.swift
// Green-on-black developer log. Debug builds only — compiled out in release.
// Displayed as a sidebar on macOS, a separate view on iOS.

import Foundation

enum LogCategory: String {
    case startup = "STARTUP  "
    case chess   = "CHESS    "
    case fleet   = "FLEET    "
    case shoot   = "SHOOT    "
    case hit     = "HIT      "
    case destroy = "DESTROY  "
    case promote = "PROMOTE  "
    case score   = "SCORE    "
    case level   = "LEVEL    "
    case input   = "INPUT    "
    case audio   = "AUDIO    "
    case error   = "ERROR    "
}

struct LogLine: Identifiable {
    let id = UUID()
    let category: LogCategory
    let message: String
    let timestamp: Date = Date()

    var categoryLabel: String { category.rawValue }
}

@Observable
final class DiagnosticsLog {
    static let shared = DiagnosticsLog()

    var lines: [LogLine] = []
    var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    var logInput: Bool = false  // INPUT events are high-frequency; off by default

    private let maxLines = 2000

    private init() {}

    func log(_ category: LogCategory, _ message: String) {
        guard isEnabled else { return }
        if category == .input && !logInput { return }

        let line = LogLine(category: category, message: message)
        Task { @MainActor in
            self.lines.append(line)
            if self.lines.count > self.maxLines {
                self.lines.removeFirst()
            }
        }
    }

    func clear() {
        Task { @MainActor in
            self.lines.removeAll()
        }
    }
}
