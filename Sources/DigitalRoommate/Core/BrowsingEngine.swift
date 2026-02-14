import Cocoa
import WebKit

// Manages the offscreen window and a pool of WKWebView instances.
// The window is positioned offscreen at (-10000, -10000) to avoid
// App Nap throttling that affects hidden/ordered-out windows.
class BrowsingEngine {

    // Maximum concurrent WKWebViews — reads from settings each time
    private var maxConcurrent: Int {
        return SettingsManager.shared.current.maxConcurrentBrowsers
    }

    // The offscreen window that hosts all WKWebViews
    private var offscreenWindow: NSWindow!

    // Active web view instances, keyed by module ID
    private var activeViews: [String: WebViewInstance] = [:]

    // Lock for thread-safe access to activeViews
    private let lock = NSLock()

    // Factory for creating web view instances — override in test mode to use mocks
    var webViewFactory: (@MainActor (String) -> WebViewInstance)? = nil

    init() {
        setupOffscreenWindow()
    }

    private func setupOffscreenWindow() {
        // Create a window positioned far offscreen — macOS won't apply
        // App Nap throttling to it because it's technically "visible"
        offscreenWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1280, height: 800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        offscreenWindow.isReleasedWhenClosed = false
        offscreenWindow.orderFront(nil)
    }

    // MARK: - Public API

    /// Get or create a WebViewInstance for a module.
    /// Returns nil if the pool is full.
    @MainActor
    func acquireWebView(for moduleId: String) -> WebViewInstance? {
        lock.lock()
        defer { lock.unlock() }

        // Return existing instance if this module already has one
        if let existing = activeViews[moduleId] {
            return existing
        }

        // Check if we're at capacity
        if activeViews.count >= maxConcurrent {
            ActivityLog.shared.log(module: moduleId, action: "WebView pool full", metadata: [
                "maxConcurrent": "\(maxConcurrent)",
                "activeModules": activeViews.keys.sorted().joined(separator: ", "),
            ])
            return nil
        }

        // Create a new instance — use the factory if set (test mode), otherwise default
        let instance: WebViewInstance
        if let factory = webViewFactory {
            instance = factory(moduleId)
        } else {
            let ua = UserAgentProvider.shared.randomUserAgent()
            let scripts = StealthScripts.allScripts
            instance = WebViewInstance(moduleId: moduleId, userAgent: ua, stealthScripts: scripts)
        }

        // Add the webview to the offscreen window
        instance.webView.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        offscreenWindow.contentView?.addSubview(instance.webView)

        activeViews[moduleId] = instance
        return instance
    }

    /// Release a WebViewInstance when a module is done with its session.
    @MainActor
    func releaseWebView(for moduleId: String) {
        lock.lock()
        defer { lock.unlock() }

        if let instance = activeViews.removeValue(forKey: moduleId) {
            instance.webView.removeFromSuperview()
            // Load blank page to release web content process memory
            instance.webView.loadHTMLString("", baseURL: nil)
        }
    }

    /// Number of active web views
    var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeViews.count
    }
}
