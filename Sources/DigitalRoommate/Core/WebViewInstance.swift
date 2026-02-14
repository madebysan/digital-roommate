import Cocoa
import WebKit

// Wraps a single WKWebView with its own cookie store, custom user agent,
// and anti-detection JS. Provides async helpers for loading URLs and
// executing JavaScript from Swift.
class WebViewInstance: NSObject, WKNavigationDelegate {

    let webView: WKWebView
    let moduleId: String
    private var navigationContinuation: CheckedContinuation<Bool, Never>?
    private var isNavigating = false

    init(moduleId: String, userAgent: String, stealthScripts: [String]) {
        self.moduleId = moduleId

        let config = WKWebViewConfiguration()

        // Each module gets its own persistent cookie store (macOS 14+)
        // This isolates cookies between search/shopping/video/news modules
        let storeId = UUID(uuidString: "00000000-0000-0000-0000-\(moduleId.padding(toLength: 12, withPad: "0", startingAt: 0))")
            ?? UUID()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: storeId)

        // Inject anti-detection scripts before any page JS runs
        for script in stealthScripts {
            let userScript = WKUserScript(
                source: script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(userScript)
        }

        // Allow inline media playback (needed for YouTube)
        config.preferences.isElementFullscreenEnabled = false

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = userAgent

        super.init()

        webView.navigationDelegate = self
    }

    // MARK: - Public API

    /// Load a URL and wait for the page to finish loading.
    /// Returns true if the page loaded successfully.
    @MainActor
    func loadURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            ActivityLog.shared.log(module: moduleId, action: "Invalid URL: \(urlString)")
            return false
        }

        isNavigating = true
        webView.load(URLRequest(url: url))

        // Wait for navigation to complete (or fail)
        let success = await withCheckedContinuation { continuation in
            self.navigationContinuation = continuation
        }

        return success
    }

    /// Execute JavaScript on the loaded page and return the result as a string.
    @MainActor
    func executeJS(_ script: String) async -> String? {
        do {
            let result = try await webView.evaluateJavaScript(script)
            if let str = result as? String {
                return str
            } else if let num = result as? NSNumber {
                return num.stringValue
            }
            return nil
        } catch {
            // JS errors are expected (e.g., element not found) — don't log as errors
            return nil
        }
    }

    /// Execute JavaScript without caring about the return value.
    @MainActor
    func runJS(_ script: String) async {
        _ = await executeJS(script)
    }

    /// Get the current page title.
    @MainActor
    func pageTitle() async -> String {
        return await executeJS("document.title") ?? "(no title)"
    }

    /// Wait for a specified number of seconds with some random jitter.
    func wait(seconds: Double, jitter: Double = 0.5) async {
        let jitterAmount = Double.random(in: -jitter...jitter)
        let totalWait = max(0.5, seconds + jitterAmount)
        try? await Task.sleep(nanoseconds: UInt64(totalWait * 1_000_000_000))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isNavigating {
            isNavigating = false
            navigationContinuation?.resume(returning: true)
            navigationContinuation = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if isNavigating {
            isNavigating = false
            ActivityLog.shared.log(module: moduleId, action: "Navigation failed: \(error.localizedDescription)")
            navigationContinuation?.resume(returning: false)
            navigationContinuation = nil
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if isNavigating {
            isNavigating = false
            ActivityLog.shared.log(module: moduleId, action: "Provisional navigation failed: \(error.localizedDescription)")
            navigationContinuation?.resume(returning: false)
            navigationContinuation = nil
        }
    }
}
