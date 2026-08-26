import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            GameSKViewRepresentable(showsDrawCount: showSidebar)

            #if DEBUG
            DiagnosticsSidebarView(isExpanded: $showSidebar)
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

// Custom NSViewRepresentable so we can control SpriteKit's debug overlays.
// SpriteView (the SwiftUI wrapper) does not expose them.
//
// fps and node count are computed in GameScene.update and shown in the sidebar.
// Draw count has no public API — SpriteKit will only report it through its own
// on-canvas overlay — so that one overlay is tied to sidebar visibility: present
// while the log is open for profiling, absent during normal play.
struct GameSKViewRepresentable: NSViewRepresentable {
    var showsDrawCount: Bool = false

    func makeNSView(context: Context) -> SKView {
        let view = KeyboardFocusedSKView()
        view.presentScene(GameScene.shared)
        applyOverlays(to: view)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        applyOverlays(to: nsView)
    }

    private func applyOverlays(to view: SKView) {
        #if DEBUG
        view.showsDrawCount = showsDrawCount
        #endif
    }
}


/// An `SKView` that claims keyboard focus as soon as it has a window.
///
/// Without this the game view is not first responder at launch, so `keyDown`
/// never reaches the scene: the title screen's "PRESS ANY KEY TO START" ignores
/// every key, and the only way in is a mouse click — which incidentally moves
/// focus here, which is why keys appear to start working afterwards.
///
/// The thief is the diagnostics sidebar. Its log is a *selectable* `NSTextView`,
/// which accepts first responder, and the sidebar is on by default in debug
/// builds — so AppKit hands it the initial focus and it silently swallows every
/// keystroke. Reproduced in isolation with this exact arrangement (SKView +
/// selectable NSTextView in a SwiftUI `HStack`): 0 keys reach the scene without
/// this class, 1 with it.
///
/// `makeNSView` is too early — there is no window yet, so `makeFirstResponder`
/// would run against nil. Claiming it again on the next run-loop turn covers
/// SwiftUI installing its own first responder after this returns.
final class KeyboardFocusedSKView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.initialFirstResponder = self
        window.makeFirstResponder(self)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.firstResponder !== self else { return }
            self.window?.makeFirstResponder(self)
        }
    }
}

extension Notification.Name {
    static let gciToggleSidebar = Notification.Name("gciToggleSidebar")
}

// MARK: - Diagnostics Sidebar

#if DEBUG
struct DiagnosticsSidebarView: View {
    @Binding var isExpanded: Bool
    private let log = DiagnosticsLog.shared

    // GCI cyan — matches the white-side piece colour
    private let accent = Color(red: 0.07, green: 0.88, blue: 1.00)

    var body: some View {
        HStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(accent)
                    .frame(width: 1)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    collapseButton
                    logScrollView
                    statsSection
                }
                .frame(width: 280)
                .background(Color.black)
            } else {
                VStack(spacing: 0) {
                    expandButton
                    Spacer()
                }
                .frame(width: 24)
                .background(Color.black)
            }
        }
    }

    // Chevron › to collapse (shown at top of expanded panel)
    private var collapseButton: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded = false }
                DiagnosticsLog.shared.log(.startup, "Sidebar hidden")
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(accent.opacity(0.45), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            .padding(.top, 6)
            Spacer()
        }
    }

    // Chevron ‹ to expand (shown in the collapsed strip)
    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded = true }
            DiagnosticsLog.shared.log(.startup, "Sidebar shown")
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(accent.opacity(0.45), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    private var statsSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(height: 1)
            HStack(spacing: 8) {
                Text(String(format: "fps: %.0f  nodes: %d", log.fps, log.nodeCount))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(accent)
                Spacer()
                Button(action: copyLog) {
                    Text("Copy")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accent.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(accent.opacity(0.7), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Copy the whole log to the clipboard")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    private var logScrollView: some View {
        LogTextView(lines: log.lines)
    }

    /// Convenience for grabbing the whole log at once; the text view itself
    /// supports ordinary selection and ⌘C for copying part of it.
    private func copyLog() {
        let text = log.lines
            .map { "\($0.categoryLabel)\($0.message)" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
#endif
