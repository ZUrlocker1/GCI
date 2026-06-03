import SwiftUI

@main
struct GalacticChessInvadersApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 700)
    }
}
