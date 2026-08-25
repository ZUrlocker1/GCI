import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            GameSKViewRepresentable()
                .ignoresSafeArea()

            #if DEBUG
            if showSidebar {
                DiagnosticsSidebarView()
                    .frame(width: 280)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .gciToggleSidebar)) { _ in
            #if DEBUG
            showSidebar.toggle()
            DiagnosticsLog.shared.log(.startup, "Sidebar \(showSidebar ? "shown" : "hidden")")
            #endif
        }
    }
}

// Custom NSViewRepresentable so we can enable SpriteKit debug overlays in debug builds.
// SpriteView (SwiftUI wrapper) does not expose showsFPS / showsNodeCount / showsDrawCount.
struct GameSKViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.presentScene(GameScene.shared)
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        view.showsDrawCount = true
        #endif
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}

extension Notification.Name {
    static let gciToggleSidebar = Notification.Name("gciToggleSidebar")
}

// MARK: - Diagnostics Sidebar

#if DEBUG
struct DiagnosticsSidebarView: View {
    private let log = DiagnosticsLog.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(log.lines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text(line.categoryLabel)
                                .foregroundColor(.green)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 72, alignment: .leading)
                            Text(line.message)
                                .foregroundColor(.white)
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .id(line.id)
                    }
                }
                .padding(8)
            }
            .background(Color.black)
            .onChange(of: log.lines.count) { _, _ in
                if let last = log.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
#endif
