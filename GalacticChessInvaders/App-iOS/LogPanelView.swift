// LogPanelView.swift
// The diagnostics log on iOS.
//
// The Mac's `LogTextView` is an `NSTextView` wrapped for SwiftUI — it is
// there for selection and ⌘C, which matter on a desktop where a tester
// copies a log into an email. §6 of docs/IOS-Port.md called it early: the
// simpler answer on iOS is a `ScrollView` of `Text`, and that is this.
//
// **Landscape only**, which is a decision already taken rather than a
// shortcut. The panel needs about 320pt beside a board that wants the rest,
// and in portrait there is nowhere for it to go that is not on top of the
// game. `L` still toggles the setting in portrait; nothing appears until the
// device is turned.

import SwiftUI

#if os(iOS)

struct LogPanelView: View {

    private static let categoryColor = Color.green
    private static let errorColor = Color.red

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.green.opacity(0.35))
            lines
        }
        .background(Color.black)
    }

    private var header: some View {
        HStack {
            Text("DIAGNOSTICS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Self.categoryColor)
            Spacer()
            // Closed through `GameSettings` rather than a local flag, so the
            // `L` key, the Settings row and this button cannot disagree —
            // the same rule the Mac panel follows.
            Button {
                GameSettings.shared.logPanel = false
                NotificationCenter.default.post(name: .gciSidebarChanged, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Self.categoryColor)
            }
            .accessibilityLabel("Close diagnostics")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var lines: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // `@Observable` means reading this tracks it: a line
                    // appended anywhere in the game redraws the list.
                    ForEach(DiagnosticsLog.shared.lines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text(line.categoryLabel)
                                .foregroundStyle(line.category == .error
                                                 ? Self.errorColor : Self.categoryColor)
                            Text(line.message)
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .id(line.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            // Follows the tail, which is the only part anyone reads while
            // the game is running.
            .onChange(of: DiagnosticsLog.shared.lines.count) {
                guard let last = DiagnosticsLog.shared.lines.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
#endif
