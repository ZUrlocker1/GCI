// FleetController.swift
// Manages the Space Invaders-style fleet movement pattern for black pieces.
// Lateral sweep → wall bounce → half-rank descent → GCIBoard.forcePlace() update.
// Logical squares update only on descent; lateral movement is visual only.
// Phase 2+: full implementation.

import Foundation

final class FleetController {
    static let shared = FleetController()
    private init() {}

    // Phase 2: fleet speed, direction, descent state, crush event callbacks
}
