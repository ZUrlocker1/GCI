// AppNotifications.swift
// The two notifications the game and its shell pass between them.
//
// They lived in App/ContentView.swift, which is the AppKit shell and is not in
// the iOS target — so `GameScene`, which posts both, stopped compiling the
// moment there was a second platform. Nothing about them is macOS-specific;
// they were simply written where they were first needed.

import Foundation

extension Notification.Name {
    /// The diagnostics sidebar opened or closed. Posted by whichever of the
    /// three routes did it — the `L` key, the Settings row, or the panel's own
    /// close button — so the other two can agree with it.
    static let gciSidebarChanged = Notification.Name("gciSidebarChanged")

    /// Test Mode was armed or disarmed. The shell listens so it can show or
    /// hide the sidebar's tab.
    static let gciTestModeChanged = Notification.Name("gciTestModeChanged")
}
