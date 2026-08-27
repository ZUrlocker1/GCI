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

    /// Bumping the app's version starts the table over.
    ///
    /// A test build is a fresh look at the game, and carrying a previous
    /// version's scores into it means whoever built it never sees what a new
    /// player sees. The scores are placeholders either way, so there is nothing
    /// worth preserving across a version.
    private let versionKey = "GCI_HighScoresVersion"

    private init() {
        let built = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        if UserDefaults.standard.string(forKey: versionKey) != built {
            UserDefaults.standard.removeObject(forKey: highScoreKey)
            UserDefaults.standard.set(built, forKey: versionKey)
        }
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

    /// What `base` is actually worth at the current multiplier. The score pop
    /// has to show the same number the total goes up by, so both round the same
    /// way — a pop reading +37 against a total that moved 38 is a bug report.
    func scaled(_ base: Int) -> Int {
        Int((Double(base) * multiplier).rounded())
    }

    /// `logged: false` for callers that print their own line — a raider says
    /// what it was worth as part of announcing that it died, and two lines for
    /// one event is one line too many.
    func addPoints(_ base: Int, source: String = "", logged: Bool = true) {
        // Rounded, not truncated: ×1.5 on a 25-point pawn is 37.5, and
        // truncating quietly paid 37 on every scaled capture.
        let points = scaled(base)
        currentScore += points
        // No running total: the HUD is showing it, and repeating it on every
        // line makes the one number that matters here — what this kill paid —
        // the hardest thing to find.
        guard logged else { return }
        DiagnosticsLog.shared.log(.score,
            "\(source.isEmpty ? "" : "\(source) ")+\(points) (×\(multiplier))")
    }

    func advanceLevel() {
        currentLevel += 1
        multiplier = 1.0 + Double(currentLevel - 1) * 0.5
        // The scene logs the level line, including this multiplier.
    }

    /// Puts the multiplier back to Level 1's without touching the score.
    ///
    /// Only the `V` skip needs this, wrapping from the last level round to the
    /// first: the ladder starts again but the run does not, so a test pass can
    /// loop without losing the total it has been watching.
    func restartLadder() {
        currentLevel = 1
        multiplier = 1.0
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

    /// Resets the table to its seeded placeholders, including what is persisted.
    /// Bound to the `X` restart so a polluted table can be cleared without
    /// deleting preferences by hand.
    ///
    /// Reseeds rather than emptying. An empty table made the wipe obvious, but a
    /// clean slate should look like a fresh install does — a first-time player
    /// never sees an empty table, so neither should anyone testing.
    func clearHighScores() {
        UserDefaults.standard.removeObject(forKey: highScoreKey)
        seedDefaultScores()
        DiagnosticsLog.shared.log(.score, "high score table reset")
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
