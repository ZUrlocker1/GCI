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
    }

    // MARK: - Scoring

    func addPoints(_ base: Int, source: String = "") {
        let points = Int(Double(base) * multiplier)
        currentScore += points
        DiagnosticsLog.shared.log(.score, "\(source.isEmpty ? "" : "\(source): ")+\(points) pts (×\(multiplier)) → \(currentScore)")
    }

    func advanceLevel() {
        currentLevel += 1
        multiplier = 1.0 + Double(currentLevel - 1) * 0.5
        DiagnosticsLog.shared.log(.level, "Level \(currentLevel) — multiplier now ×\(multiplier)")
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
