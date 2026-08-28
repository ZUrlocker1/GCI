// LogTextView.swift
// The diagnostics log, as a plain scrolling text view.
//
// This replaced a SwiftUI list of one Text per line. That gave each row its own
// view, so selection could not span rows — you could copy one line or nothing.
// A log wants ordinary text behaviour: drag across as much as you like, ⌘C,
// ⌘A. NSTextView gives that for free, and appending to its storage is cheaper
// than rebuilding a list of a couple of thousand views.

import SwiftUI
import AppKit
import QuartzCore

struct LogTextView: NSViewRepresentable {

    var lines: [LogLine]

    private static let fontSize: CGFloat = 11
    private static let categoryColor = NSColor.systemGreen
    private static let messageColor = NSColor.white
    /// The ERROR label only. A whole line in red is harder to read than it is
    /// eye-catching, and the label alone is enough to find in a wall of green.
    private static let errorColor = NSColor.systemRed

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .black
        textView.textContainerInset = NSSize(width: 6, height: 6)
        // Long lines wrap rather than forcing a horizontal scrollbar.
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black

        context.coordinator.textView = textView
        context.coordinator.sync(to: lines)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.sync(to: lines)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Tracks what has already been rendered so each update appends only the new
    /// lines instead of rebuilding the whole document.
    @MainActor
    final class Coordinator {
        weak var textView: NSTextView?
        /// Identity of the last line written, so we can find our place again even
        /// though the log trims from the front once it hits its cap.
        private var lastRenderedID: UUID?

        /// Appends only what is new. The log is append-only, so a sync never
        /// has to rewrite anything — it finds its place by the identity of the
        /// last line it wrote and adds whatever came after.
        ///
        /// This used to sit behind a 10Hz throttle, on the reasoning that
        /// `isScrolledToBottom` makes TextKit lay out the whole document and
        /// SwiftUI could offer an update every frame. The throttle held state —
        /// a `flushScheduled` flag and a deadline — that only reset when the
        /// view was rebuilt, and it stopped the panel updating until you
        /// collapsed and reopened it. Silently freezing the tool you diagnose
        /// with is the worst possible place for that, and the CPU problem it
        /// was written for turned out to be the node leak, fixed elsewhere.
        /// `updateNSView` fires when a line is appended, which in play is a few
        /// times a second, not sixty.
        func sync(to lines: [LogLine]) {
            guard let textView, let storage = textView.textStorage else { return }

            let newLines: [LogLine]
            if let lastRenderedID,
               let index = lines.lastIndex(where: { $0.id == lastRenderedID }) {
                newLines = Array(lines[(index + 1)...])
            } else if lastRenderedID == nil {
                newLines = lines
            } else {
                // The anchor fell off the front when the log trimmed, so start over.
                storage.setAttributedString(NSAttributedString())
                newLines = lines
            }

            guard !newLines.isEmpty else { return }

            // Only auto-scroll when the view is already at the bottom, so reading
            // back through history is not yanked away by incoming lines.
            let wasAtBottom = isScrolledToBottom(textView)

            storage.beginEditing()
            for line in newLines { storage.append(Self.rendered(line)) }
            storage.endEditing()

            lastRenderedID = lines.last?.id
            if wasAtBottom { textView.scrollToEndOfDocument(nil) }
        }

        private func isScrolledToBottom(_ textView: NSTextView) -> Bool {
            guard let clip = textView.enclosingScrollView?.contentView else { return true }
            let visibleMaxY = clip.bounds.maxY
            let documentMaxY = textView.bounds.maxY
            // A few points of slack so "close enough" still counts.
            return documentMaxY - visibleMaxY < 8
        }

        private static func rendered(_ line: LogLine) -> NSAttributedString {
            let font = NSFont.monospacedSystemFont(ofSize: LogTextView.fontSize, weight: .regular)
            let isError = line.category == .error
            let result = NSMutableAttributedString(
                string: line.categoryLabel,
                attributes: [.font: font,
                             .foregroundColor: isError ? LogTextView.errorColor
                                                       : LogTextView.categoryColor])
            result.append(NSAttributedString(
                string: line.message + "\n",
                attributes: [.font: font, .foregroundColor: LogTextView.messageColor]))
            return result
        }
    }
}
