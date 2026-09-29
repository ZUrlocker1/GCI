// TouchInputAdapter.swift
// The iOS sibling of MacInputAdapter: fingers into the same neutral calls a
// mouse makes, plus the two controls a mouse never needed.
//
// docs/IOS-Port.md §4 settles the scheme, and it is one rule: **on iOS you
// drag things.** The ship in its lane, a piece to its square. The only tap is
// the fire button.
//
//   · a touch on FIRE holds fire until it lifts
//   · a touch in the ship's lane drags the ship, one to one
//   · anything else is a pointer — the board, the panels, the sliders, which
//     `GameScene` already handles because the Mac refactor left
//     `pointerDown(at:)` behind for exactly this
//
// **Every touch is tracked by identity.** Reading `touches.first` was the
// first version and it makes the two thumbs fight: a right thumb resting on
// FIRE becomes "first" and steals the left thumb's drag. `UITouch` instances
// persist across phases, so their `ObjectIdentifier` is the handle.
//
// Auto-fire is deliberately absent. In GCI your own pieces sit in the firing
// line on every shot, so firing has to be a decision the player makes.

import SpriteKit

#if os(iOS)
import UIKit

extension GameScene {

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let id = ObjectIdentifier(touch)

            if let fireButton, fireButton.contains(scenePoint: point), acceptsTouchControls {
                fireTouch = id
                setTouchFiring(true)
                continue
            }
            if acceptsTouchControls, isInShipLane(point) {
                shipDragTouch = id
                // Grabs without moving: the ship keeps its distance from the
                // finger for the rest of the drag, so a thumb never ends up
                // on top of it.
                beginShipDrag(at: point.x)
                continue
            }
            pointerDown(at: point)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let id = ObjectIdentifier(touch)

            if id == shipDragTouch {
                continueShipDrag(to: point.x)
                continue
            }
            // A finger that started on FIRE keeps firing wherever it slides;
            // lifting is what stops it. Sliding off a button and expecting it
            // to stop is a desktop habit, and mid-fight it would read as the
            // gun jamming.
            if id == fireTouch { continue }
            pointerDragged(to: point)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if id == fireTouch {
                fireTouch = nil
                setTouchFiring(false)
                continue
            }
            if id == shipDragTouch {
                shipDragTouch = nil
                continue
            }
            pointerUp()
        }
    }

}
#endif
