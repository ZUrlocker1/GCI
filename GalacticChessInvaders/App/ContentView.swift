import SwiftUI
import SpriteKit

struct ContentView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Main game view
            SpriteView(scene: GameScene.shared)
                .ignoresSafeArea()

            // Diagnostics sidebar (debug builds only)
            #if DEBUG
            DiagnosticsSidebarView()
                .frame(width: 280)
            #endif
        }
    }
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
