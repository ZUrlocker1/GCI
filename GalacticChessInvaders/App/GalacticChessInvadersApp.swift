import SwiftUI
import CoreText

@main
struct GalacticChessInvadersApp: App {

    init() {
        registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 700)
    }

    // Register fonts from the app bundle so SpriteKit (and SwiftUI) can use them
    // by PostScript name — e.g. "PressStart2P-Regular" — without Info.plist entries.
    private func registerBundledFonts() {
        let fontNames = ["PressStart2P-Regular"]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                DiagnosticsLog.shared.log(.error, "Font not found in bundle: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                DiagnosticsLog.shared.log(.startup, "Font registered: \(name)")
            } else {
                // Already registered (e.g. second run) is not an error
                DiagnosticsLog.shared.log(.startup, "Font already registered: \(name)")
            }
        }
    }
}
