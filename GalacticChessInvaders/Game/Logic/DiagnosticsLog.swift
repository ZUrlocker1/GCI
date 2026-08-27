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
    /// Raiders (§6) — the only things that run on a real-time clock rather
    /// than the chess beat, so they are worth following on their own.
    case raider  = "RAIDER   "
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
    private static let trimChunk = 200

    private init() {}

    /// `@autoclosure`, so the message is only *built* if it will be kept.
    ///
    /// Every call site interpolates a string — "\(square) rejoins", "ship fires
    /// 2/2" — and there are eighty of them, the hot ones firing on every shot
    /// and every hit. As a plain `String` parameter that interpolation runs
    /// before the call, so a release build, where `isEnabled` is false, paid to
    /// construct and immediately discard tens of strings a second. Deferring it
    /// costs nothing when logging is on and removes the work entirely when it is
    /// off.
    func log(_ category: LogCategory, _ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        if category == .input && !logInput { return }
        lines.append(LogLine(category: category, message: message()))
        // Trimmed in chunks, not one at a time. `removeFirst()` on an Array
        // shifts every remaining element, so at the cap each new line moved two
        // thousand of them — a cost that appears only once the log fills, which
        // is exactly the shape of "CPU climbs for the first few minutes and then
        // settles". One shift per two hundred lines instead of one per line.
        if lines.count > maxLines { lines.removeFirst(Self.trimChunk) }
    }

    func clear() { lines.removeAll() }
}
