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
        let built = Bundle.main.appVersion
        if UserDefaults.standard.string(forKey: versionKey) != built {
            UserDefaults.standard.removeObject(forKey: highScoreKey)
            UserDefaults.standard.set(built, forKey: versionKey)
        }
        loadHighScores()
        if highScores.isEmpty { seedDefaultScores() }
    }

    /// Placeholders so the table is not empty on a first run — and a bar worth
    /// clearing rather than a formality.
    ///
    /// They were 60-100, which any first game beat inside a minute; a table
    /// that congratulates you for playing badly is not a high score table.
    /// Calibrated instead against ten recorded games, whose median was about
    /// 1000: the visible floor turns away half of those, including a run that
    /// reached Level 8 and one that reached Level 7 — getting deep while
    /// shooting badly should not chart. The top is under the best recorded
    /// 10,953, so first place is reachable rather than a wall, and every entry
    /// sits well under the ~39,000 a perfect ten-wave run is worth.
    ///
    /// All ten slots are filled, not just the five the title screen shows.
    /// `isHighScore` is true whenever the table has a free slot, so seeding
    /// only the visible five left five empty ones and the first five games of a
    /// new install were prompted for a name whatever they scored — the thing
    /// these numbers exist to prevent. The tail is never displayed; it is there
    /// to close that door, and 750 is the real bar for being asked to sign.
    private func seedDefaultScores() {
        highScores = [
            HighScoreEntry(initials: "ZACK",    score: 8000, level: 6),
            HighScoreEntry(initials: "BEN",     score: 5000, level: 6),
            HighScoreEntry(initials: "STEVE",   score: 3000, level: 5),
            HighScoreEntry(initials: "WOZ",     score: 2000, level: 4),
            HighScoreEntry(initials: "NOLAN",   score: 1000, level: 3),
            // Below the fold. Arcade forebears, in the spirit of the two above.
            HighScoreEntry(initials: "TOMO",    score:  950, level: 3),
            HighScoreEntry(initials: "TORU",    score:  900, level: 3),
            HighScoreEntry(initials: "DONA",    score:  850, level: 2),
            HighScoreEntry(initials: "RUSSELL", score:  800, level: 2),
            HighScoreEntry(initials: "ALCORN",  score:  750, level: 2),
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
        DiagnosticsLog.shared.log(.score, "\(entry.initials) \(entry.score)")
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
