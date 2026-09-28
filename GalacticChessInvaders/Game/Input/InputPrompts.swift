// InputPrompts.swift
// The copy that names a control, in one place.
//
// docs/IOS-Port.md §4: the game may not promise keys the device does not
// have. "PRESS ANY KEY TO START" on an iPad is the first thing anyone hits,
// and it is a lie with no way out of it.
//
// "TAP ANYWHERE" rather than "TAP", deliberately. "Any key" means *no target
// to aim at*, and the title screen has two real targets on it in SET and
// INFO — "TAP TO START" would leave a player wondering whether the words
// themselves are the button.
//
// Deliberately per-platform and not per-keyboard. A hardware keyboard on an
// iPad drives every key the Mac does (see `KeyboardInputAdapter`), so the
// wording is arguably wrong for that case — but making the copy watch for a
// keyboard means labels that contradict themselves depending on when they
// were built, `@MainActor` on an enum that has no other reason to want it,
// and a rebuild to notice a keyboard arriving. The How To Play screen names
// the keys instead, which is where someone with a keyboard will look.

import Foundation

enum InputPrompts {

    /// Title screen.
    static var start: String {
        #if os(macOS)
        "PRESS ANY KEY TO START"
        #else
        "TAP ANYWHERE TO START"
        #endif
    }

    /// The pause overlay, where any input resumes.
    static var resume: String {
        #if os(macOS)
        "PRESS ANY KEY TO RESUME"
        #else
        "TAP ANYWHERE TO RESUME"
        #endif
    }

    /// The footer of Settings and How To Play. These *do* have a target —
    /// the BACK button — so name it rather than saying "anywhere".
    static var resumeFromPanel: String {
        #if os(macOS)
        "PRESS ANY KEY TO RESUME GAME"
        #else
        "TAP BACK TO RESUME"
        #endif
    }

    /// The wave-clear overlay, which carries the next level's number.
    /// Unpadded: `OutcomePresentationTests` reads "LEVEL 3", and the banner
    /// has said it that way since 0.2.
    static func nextLevel(_ level: Int) -> String {
        #if os(macOS)
        "PRESS ANY KEY  ·  LEVEL \(level)"
        #else
        "TAP FOR LEVEL \(level)"
        #endif
    }
}
