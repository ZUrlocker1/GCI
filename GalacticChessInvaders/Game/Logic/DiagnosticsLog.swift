// DiagnosticsLog.swift
// Green-on-black developer log. Debug builds only — compiled out in release.
// Displayed as a sidebar on macOS, a separate view on iOS.
// @MainActor: always accessed from the main thread (SpriteKit game loop + SwiftUI).

import Foundation

enum LogCategory: String {
    case startup = "STARTUP  "
    // Moves are tagged by side rather than a generic CHESS, so scanning the log
    // shows at a glance who moved.
    case white   = "WHITE    "
    case black   = "BLACK    "
    case chess   = "CHESS    "
    case fleet   = "FLEET    "
    /// Piece regeneration and armored pawns (§23.9, §10.1). Its own category
    /// rather than more FLEET lines: a regeneration plays out over three
    /// separate moments seconds apart, and following one through a wave's worth
    /// of sweep and descent chatter is the point of having categories at all.
    case regen   = "REGEN    "
    case shoot   = "SHOOT    "
    case hit     = "HIT      "
    case destroy = "DESTROY  "
    case promote = "PROMOTE  "
    case score   = "SCORE    "
    case level   = "LEVEL    "
    case input   = "INPUT    "
    case audio   = "AUDIO    "
    case error   = "ERROR    "
    /// Standalone banner lines that read as the whole message, e.g. RESTART.
    case restart = "RESTART  "
    case auto    = "AUTOMODE "
    case info    = "INFO     "
}

struct LogLine: Identifiable {
    let id = UUID()
    let category: LogCategory
    let message: String
    let timestamp: Date = Date()

    var categoryLabel: String { category.rawValue }
}

@MainActor
@Observable
final class DiagnosticsLog {
    static let shared = DiagnosticsLog()

    var lines: [LogLine] = []
    var fps: Double = 60.0
    var nodeCount: Int = 0
    var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    var logInput: Bool = false

    private let maxLines = 2000

    private init() {}

    func log(_ category: LogCategory, _ message: String) {
        guard isEnabled else { return }
        if category == .input && !logInput { return }
        lines.append(LogLine(category: category, message: message))
        if lines.count > maxLines { lines.removeFirst() }
    }

    func clear() { lines.removeAll() }
}
