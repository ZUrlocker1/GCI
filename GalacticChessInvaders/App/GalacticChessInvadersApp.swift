import SwiftUI
import CoreText
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Command-Q mid-run asks first.
    ///
    /// `Q` on its own puts up "QUIT GAME? Y / N", and the modified version was
    /// throwing the same game away without a word. Only while a wave is
    /// actually being played — from the title screen or the game over menu
    /// there is nothing to lose and the prompt would just be in the way.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard GameScene.shared.stateMachine.currentState is PlayingState else {
                return .terminateNow
            }
            let alert = NSAlert()
            alert.messageText = "Quit Galactic Chess Invaders?"
            alert.informativeText = "The game you are playing will be lost."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
    }
}

@main
struct GalacticChessInvadersApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // First line in the log, before anything else has a chance to write one.
        // The log is debug-only, so this is the one place the hidden test keys
        // are written down where someone will actually see them.
        DiagnosticsLog.shared.log(.startup, "Test modes A, P, R, V")
        registerBundledFonts()
        // Every SFX player is built and prepared here so gameplay never touches
        // the filesystem (§18: zero I/O during play).
        AudioManager.shared.preloadAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 500)
                .onAppear { applyAppIcon() }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 700)
        .commands { gameCommands }
    }

    /// A menu bar that matches the game.
    ///
    /// SwiftUI's defaults hand a game an Edit menu full of Undo, Cut, Copy and
    /// Paste, none of which does anything here — an empty menu reads as
    /// unfinished. Those groups are replaced with nothing, and a Game menu
    /// takes their place so the controls are discoverable without opening How
    /// To Play.
    ///
    /// Every shortcut is Command-modified. A menu key equivalent is consumed
    /// before the key ever reaches the scene, so a bare letter here would
    /// silently steal it from the game.
    @CommandsBuilder
    private var gameCommands: some Commands {
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(replacing: .pasteboard) { }
        CommandGroup(replacing: .textEditing) { }

        CommandGroup(replacing: .newItem) {
            Button("New Game") { MainActor.assumeIsolated { GameScene.shared.startNewGame() } }
                .keyboardShortcut("n")
        }

        CommandMenu("Game") {
            Button("Settings…") { MainActor.assumeIsolated { GameScene.shared.showSettings() } }
                .keyboardShortcut(",")
            Button("How To Play") { MainActor.assumeIsolated { GameScene.shared.showHowToPlay() } }
                .keyboardShortcut("i")
            Divider()
            Button("Back to Title") { MainActor.assumeIsolated { GameScene.shared.resetToTitle() } }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }
    }

    // Force-set the app icon at runtime so macOS LaunchServices cache cannot show a blank icon.
    // NSApp is guaranteed non-nil by the time .onAppear fires.
    private func applyAppIcon() {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = image
    }

    private func registerBundledFonts() {
        let fontNames = ["PressStart2P-Regular"]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                DiagnosticsLog.shared.log(.error, "Font not found in bundle: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                DiagnosticsLog.shared.log(.startup, "Font \(name)")
            } else {
                DiagnosticsLog.shared.log(.startup, "Font already registered: \(name)")
            }
        }
    }
}
