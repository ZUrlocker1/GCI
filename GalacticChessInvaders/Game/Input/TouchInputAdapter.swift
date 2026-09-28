// TouchInputAdapter.swift
// The iOS sibling of MacInputAdapter: `UITouch` into the same neutral pointer
// calls a mouse makes.
//
// This is short because the work was done already. `GameScene` stopped taking
// `NSEvent` when the Mac adapter was lifted out of it, and what was left —
// `pointerDown(at:)`, `pointerDragged(to:)`, `pointerUp()` — describes a
// finger just as well as a mouse. So one tap now starts the game, picks a
// chess piece, names its destination, works SET and INFO, both BACK buttons
// and the Settings sliders, with no change to any of them.
//
// What a finger is NOT: the ship. Steering and firing want a virtual
// controller (§4), and that is the next piece.

import SpriteKit

#if os(iOS)
import UIKit

extension GameScene {

    /// The first touch only. The game has no two-finger gesture, and reading
    /// them all would let a palm on the bezel fight the finger that meant it.
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerDown(at: touch.location(in: self))
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerDragged(to: touch.location(in: self))
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pointerUp()
    }

    /// A touch the system takes away — a call arriving, a system gesture. It
    /// has to end the drag, or a Settings slider stays captured and the next
    /// tap anywhere drags it.
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pointerUp()
    }
}
#endif
