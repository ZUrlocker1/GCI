import SwiftUI
import CoreText
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Strips the menus SwiftUI insists on and this game has no use for.
    ///
    /// There is no way to decline File, View or Window through `.commands` —
    /// emptying their command groups leaves the menu behind with whatever
    /// SwiftUI puts there regardless. Removing them from the built menu is the
    /// only reliable way, and it has to happen after SwiftUI has built it.
    ///
    /// Matched by title, which is English-only. This app has no localisation,
    /// and a menu that fails to disappear is a cosmetic problem rather than a
    /// broken one.
    ///
    /// Window goes with the rest, and `⌘M` to minimise goes with it — a
    /// deliberate trade for a single-window game that wants its menu bar to
    /// read as short.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let main = NSApp.mainMenu else { return }
        for title in ["File", "View", "Window"] {
            if let item = main.items.first(where: { $0.title == title }) {
                main.removeItem(item)
            }
        }
    }

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
        // The log panel is a system-font text view, so the glyph renders here
        // without the two-font dance the How To Play screen needs.
        DiagnosticsLog.shared.log(.startup, "Test Mode ⌘T  A, P, R, V")
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
        // Undo and Find go; the pasteboard group stays. The diagnostics panel is
        // a real NSTextView and Command-C reaches it through Edit > Copy — take
        // that menu item away and the shortcut stops working, which is how it
        // broke once already.
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(replacing: .textEditing) { }
        CommandGroup(replacing: .newItem) { }

        CommandMenu("Game") {
            Button("New Game") { MainActor.assumeIsolated { GameScene.shared.startNewGame() } }
                .keyboardShortcut("n")
            Divider()
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
