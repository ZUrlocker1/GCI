import SwiftUI
import CoreText
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
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
