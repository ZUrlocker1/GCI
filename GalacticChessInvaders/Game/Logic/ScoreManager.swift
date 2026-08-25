// ScoreManager.swift
// Score tracking, multiplier, and UserDefaults high score persistence.
// Pure Swift — no SpriteKit.

import Foundation

struct HighScoreEntry: Codable {
    var initials: String    // up to 8 characters
    var score: Int
    var level: Int
}

@MainActor
@Observable
final class ScoreManager {
    static let shared = ScoreManager()

    private(set) var currentScore: Int = 0
    private(set) var currentLevel: Int = 1
    private(set) var multiplier: Double = 1.0
    private(set) var highScores: [HighScoreEntry] = []

    private let highScoreKey = "GCI_HighScores"
    private let maxHighScores = 10

    private init() {
        loadHighScores()
        if highScores.isEmpty { seedDefaultScores() }
    }

    /// Placeholders so the table is not empty on a first run. Deliberately tiny,
    /// so any real game displaces them instead of them squatting the top five.
    private func seedDefaultScores() {
        highScores = [
            HighScoreEntry(initials: "ZACK",  score: 100, level: 1),
            HighScoreEntry(initials: "BEN",   score:  90, level: 1),
            HighScoreEntry(initials: "STEVE", score:  80, level: 1),
            HighScoreEntry(initials: "WOZ",   score:  70, level: 1),
            HighScoreEntry(initials: "NOLAN", score:  60, level: 1),
        ]
    }

    // MARK: - Scoring

    func addPoints(_ base: Int, source: String = "") {
        // Rounded, not truncated: ×1.5 on a 25-point pawn is 37.5, and
        // truncating quietly paid 37 on every scaled capture.
        let points = Int((Double(base) * multiplier).rounded())
        currentScore += points
        DiagnosticsLog.shared.log(.score, "\(source.isEmpty ? "" : "\(source): ")+\(points) pts (×\(multiplier)) → \(currentScore)")
    }

    func advanceLevel() {
        currentLevel += 1
        multiplier = 1.0 + Double(currentLevel - 1) * 0.5
        // The scene logs the level line, including this multiplier.
    }

    func resetForNewGame() {
        currentScore = 0
        currentLevel = 1
        multiplier = 1.0
    }

    // MARK: - High Scores

    func topHighScores(limit: Int) -> [HighScoreEntry] {
        Array(highScores.prefix(limit))
    }

    var isHighScore: Bool {
        highScores.count < maxHighScores || currentScore > (highScores.last?.score ?? 0)
    }

    func submitHighScore(initials: String) {
        let entry = HighScoreEntry(
            initials: String(initials.prefix(8)).uppercased(),
            score: currentScore,
            level: currentLevel
        )
        highScores.append(entry)
        highScores.sort { $0.score > $1.score }
        if highScores.count > maxHighScores {
            highScores = Array(highScores.prefix(maxHighScores))
        }
        saveHighScores()
        DiagnosticsLog.shared.log(.score, "High score submitted: \(entry.initials) \(entry.score) L\(entry.level)")
    }

    /// Wipes the table completely, including what is persisted. Bound to the `X`
    /// restart so a polluted table can be cleared without deleting preferences
    /// by hand. Deliberately leaves it empty rather than reseeding, so it is
    /// obvious the wipe happened.
    func clearHighScores() {
        highScores = []
        UserDefaults.standard.removeObject(forKey: highScoreKey)
        DiagnosticsLog.shared.log(.score, "high score table cleared")
    }

    private func saveHighScores() {
        if let data = try? JSONEncoder().encode(highScores) {
            UserDefaults.standard.set(data, forKey: highScoreKey)
        }
    }

    private func loadHighScores() {
        guard let data = UserDefaults.standard.data(forKey: highScoreKey),
              let scores = try? JSONDecoder().decode([HighScoreEntry].self, from: data)
        else { return }
        highScores = scores
    }
}
