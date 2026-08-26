// FleetFiring.swift
// Decides which fleet pieces fire an invader shot each beat, and how many
// (§5.3, §21.1). Pure decisions, no SpriteKit — GameScene spawns the actual
// LaserNode at whatever square this picks.

import Foundation

enum FleetFiring {

    /// How many pieces fire this beat, from the level's `shotsPerTurn` range.
    /// Level 1's range is 0...0, so it fires nothing there with no special case.
    static func shotCount(for level: LevelParameters) -> Int {
        Int.random(in: level.shotsPerTurn)
    }

    /// Picks up to `count` distinct squares to fire from, weighted toward the
    /// front rank — the rank closest to White, i.e. the lowest rank number a
    /// fleet piece currently holds (§5.3: "weighted toward front-rank pawns").
    /// Returns fewer than `count` if there aren't enough squares to choose from.
    static func chooseShooters(from squares: [String], count: Int) -> [String] {
        guard count > 0, !squares.isEmpty else { return [] }

        func rank(_ square: String) -> Int { Int(String(square.last ?? "1")) ?? 1 }

        // Rank 2 gets the heaviest weight (rank 1 would be a breach, so it
        // never appears here); the weight tapers down to 1 by rank 8.
        var pool: [String] = []
        for square in squares {
            let weight = max(1, 9 - rank(square))
            pool.append(contentsOf: Array(repeating: square, count: weight))
        }

        var chosen: [String] = []
        while chosen.count < count, !pool.isEmpty {
            let pick = pool.remove(at: Int.random(in: 0..<pool.count))
            chosen.append(pick)
            // Once picked, every remaining copy of this square is removed too
            // — it can't be chosen twice, and the loop is guaranteed to shrink
            // the pool by at least one distinct square per iteration.
            pool.removeAll { $0 == pick }
        }
        return chosen
    }
}
