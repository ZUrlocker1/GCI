// GCIiOSApp.swift
// The iOS shell: the twin of App/GalacticChessInvadersApp.swift and
// App/ContentView.swift, which are AppKit and excluded from this target.
//
// Everything below is Phase 1 of docs/IOS-Port.md §9 — the platform work with
// no macOS equivalent. The game itself is untouched: `GameScene.shared` is the
// same scene the Mac runs, because `SceneLayout` and `KeyPress` already took
// the two things that were in its way out of it.
//
// What is deliberately NOT here yet:
//   · the virtual controller and touch chess — Phase 1's input half
//   · the diagnostics log — landscape only, and it needs a SwiftUI rewrite
//     first (App/LogTextView.swift is an NSTextView)
//   · any layout decision. That is Pass 1, and it wants a device.

import SwiftUI
import SpriteKit
import AVFoundation

@main
struct GCIiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AudioSession.configure()
        // Everything the Mac shell does at launch that is not AppKit.
        //
        // `App/GalacticChessInvadersApp.swift` is excluded from this target,
        // and `preloadAll` was the line in it that mattered: every SFX player
        // is built and prepared there so gameplay never touches the
        // filesystem (§18). Without it the pools are empty and `play` returns
        // silently — which is exactly what shipped in the first iOS build,
        // music playing and not one sound effect.
        //
        // The font needs no equivalent: `UIAppFonts` in Info-iOS.plist does
        // what `registerBundledFonts()` does over there.
        MainActor.assumeIsolated {
            DiagnosticsLog.shared.log(.startup, "Test Mode ⌘T  A, P, R, V")
            AudioManager.shared.preloadAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The board is black to the edges; a white letterbox under the
                // home indicator would be the first thing anyone noticed.
                .ignoresSafeArea()
                .statusBarHidden()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            Lifecycle.handle(phase)
        }
    }
}

// MARK: - Audio

/// `AVAudioPlayer` makes no sound on iOS until a session is configured and
/// active — there is no equivalent step on macOS, and it is the single most
/// common reason a ported game ships silent.
enum AudioSession {

    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.ambient` rather than `.playback`: this is a game with a
            // soundtrack, not a music player. Ambient is what lets someone
            // keep their own music going underneath, and it respects the
            // ringer switch, which players expect of a game.
            //
            // `.mixWithOthers` says so explicitly rather than relying on the
            // category's default, since that default has moved before.
            try session.setCategory(.ambient, mode: .default,
                                    options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Hopped rather than isolated: this runs from `App.init`, which
            // Swift 6 does not consider main-actor even though it is.
            let message = error.localizedDescription
            Task { @MainActor in
                DiagnosticsLog.shared.log(.error, "audio session: \(message)")
            }
        }
    }

    /// Interruptions — a phone call, Siri, another app taking the route — stop
    /// every `AVAudioPlayer` without telling the game. Reactivating is what
    /// brings the soundtrack back; without this the music simply never returns.
    static func reactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in
                DiagnosticsLog.shared.log(.error, "audio resume: \(message)")
            }
        }
    }
}

// MARK: - Lifecycle

/// Backgrounding on iOS is aggressive and routine — a notification, a swipe
/// up, the screen locking. On macOS the window simply loses focus and the game
/// carries on, which is why none of this exists over there.
enum Lifecycle {

    @MainActor
    static func handle(_ phase: ScenePhase) {
        let scene = GameScene.shared
        switch phase {
        case .active:
            AudioSession.reactivate()
            scene.isPaused = false
            // Coming back from the background, the keyboard has to be claimed
            // again — the app was not first responder while it was away.
            (scene.view as? KeyboardFocusedSKView)?.claimKeyboard()
            DiagnosticsLog.shared.log(.info, "foreground")
        case .inactive, .background:
            // Pause the scene rather than the game's own pause state: this is
            // not the player asking for a break, and coming back should not
            // put them in a menu. The turn clock stops because everything on
            // the scene's clock stops.
            scene.isPaused = true
            DiagnosticsLog.shared.log(.info, "background")
        @unknown default:
            break
        }
    }
}

// MARK: - Root

/// The game, and the diagnostics panel beside it when it is open.
///
/// Side by side rather than overlaid, which is what the Mac does — the SKView
/// simply gets narrower and `SceneLayout` lays the game out in what is left.
/// That is the responsive work from 1.2 earning its keep twice: the panel
/// costs no special handling, it is just a smaller scene.
struct RootView: View {

    @State private var showLog = GameSettings.shared.logPanel

    var body: some View {
        GeometryReader { geometry in
            // Landscape only — a decision, not a shortcut. See `LogPanelView`.
            let isLandscape = geometry.size.width > geometry.size.height
            HStack(spacing: 0) {
                GameView()
                if showLog && isLandscape {
                    LogPanelView()
                        .frame(width: min(320, geometry.size.width * 0.32))
                }
            }
        }
        // Re-reads rather than flips, so setting the switch to the state it
        // is already in cannot close the panel.
        .onReceive(NotificationCenter.default.publisher(for: .gciSidebarChanged)) { _ in
            guard showLog != GameSettings.shared.logPanel else { return }
            showLog = GameSettings.shared.logPanel
        }
    }
}

// MARK: - The scene, in SwiftUI

struct GameView: UIViewRepresentable {

    func makeUIView(context: Context) -> SKView {
        // Not a plain `SKView`: this one claims the keyboard and routes what
        // it gets to the scene. See `KeyboardFocusedSKView`.
        let view = KeyboardFocusedSKView()
        view.ignoresSiblingOrder = true
        // Off in a shipping build. They are the first thing a reviewer would
        // photograph, and the diagnostics panel carries the same figures.
        view.showsFPS = false
        view.showsNodeCount = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        // Asked again on every update, not just at creation: the window is
        // often not key yet when the view first appears, and a press that
        // arrives before the game holds the keyboard goes to iPadOS instead —
        // which is Space opening Spotlight over the title screen.
        (view as? KeyboardFocusedSKView)?.claimKeyboard()
        guard view.scene == nil else { return }
        let scene = GameScene.shared
        // `.resizeFill` on both platforms: the scene *is* the view, and
        // `SceneLayout` lays the game out from whatever size that turns out to
        // be. This is the whole payoff of the 1.2 refactor — there is no iOS
        // branch here because there does not need to be one.
        scene.scaleMode = .resizeFill
        scene.size = view.bounds.size
        view.presentScene(scene)
    }
}
