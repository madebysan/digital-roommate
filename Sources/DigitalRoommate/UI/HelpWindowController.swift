import Cocoa
import SwiftUI

// Thin wrapper that hosts the SwiftUI HelpView in an NSWindow.
// Singleton — calling show() again brings the existing window to front.
class HelpWindowController: NSWindowController {

    static let shared = HelpWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 720)),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Digital Roommate"
        window.center()
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: HelpView())
        window.contentView = hostingView

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
