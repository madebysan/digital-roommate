import Cocoa
import SwiftUI

// Thin wrapper that hosts the SwiftUI OnboardingView in an NSWindow.
class OnboardingWindowController: NSWindowController {

    // Callback fired when the user finishes onboarding
    var onComplete: (() -> Void)?

    static var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 560, height: 520)),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Digital Roommate"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.window?.close()
            self?.onComplete?()
        })
        window.contentView = NSHostingView(rootView: onboardingView)
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
