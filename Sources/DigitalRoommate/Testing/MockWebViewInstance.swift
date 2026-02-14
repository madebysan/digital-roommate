import Cocoa
import WebKit

// A mock web view that logs everything but doesn't actually load URLs.
// Used in test mode to verify module behavior without hitting real websites.
// Subclasses WebViewInstance so modules can use it without knowing it's fake.
class MockWebViewInstance: WebViewInstance {

    // Track every call for analysis
    private(set) var loadedURLs: [String] = []
    private(set) var executedJS: [String] = []

    override init(moduleId: String, userAgent: String, stealthScripts: [String]) {
        super.init(moduleId: moduleId, userAgent: userAgent, stealthScripts: stealthScripts)
    }

    // MARK: - Overrides (no real loading, immediate return)

    @MainActor
    override func loadURL(_ urlString: String) async -> Bool {
        loadedURLs.append(urlString)

        // Simulate a realistic page title based on the URL domain
        let title = MockWebViewInstance.simulatedTitle(for: urlString)

        ActivityLog.shared.log(module: moduleId, action: "Mock loadURL", metadata: [
            "url": urlString,
            "simulatedTitle": title,
        ])

        // Simulate a tiny delay (but much faster than a real page load)
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        return true
    }

    @MainActor
    override func executeJS(_ script: String) async -> String? {
        executedJS.append(script)

        ActivityLog.shared.log(module: moduleId, action: "Mock executeJS", metadata: [
            "scriptPrefix": String(script.prefix(100)),
        ])

        // Return realistic mock values based on what the JS is trying to do
        return MockWebViewInstance.simulatedJSResult(for: script)
    }

    @MainActor
    override func runJS(_ script: String) async {
        executedJS.append(script)
        // Don't log scrollBy/click/play — they're noise that floods the log
    }

    @MainActor
    override func pageTitle() async -> String {
        // Return a title based on the last loaded URL
        if let lastUrl = loadedURLs.last {
            return MockWebViewInstance.simulatedTitle(for: lastUrl)
        }
        return "(mock page)"
    }

    // Wait a compressed amount (real seconds / 100) so time-based loops still work
    // but finish 100x faster than real browsing
    override func wait(seconds: Double, jitter: Double = 0.5) async {
        let compressed = max(0.01, seconds / 100.0)
        try? await Task.sleep(nanoseconds: UInt64(compressed * 1_000_000_000))
    }

    // MARK: - Simulated Responses

    /// Generate a realistic page title from a URL
    static func simulatedTitle(for urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return "(mock page)"
        }

        if host.contains("google.com") {
            // Extract query from Google search URL
            if let query = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "q" })?.value {
                return "\(query) - Google Search"
            }
            return "Google"
        }
        if host.contains("bing.com") {
            if let query = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "q" })?.value {
                return "\(query) - Bing"
            }
            return "Bing"
        }
        if host.contains("duckduckgo.com") {
            if let query = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "q" })?.value {
                return "\(query) at DuckDuckGo"
            }
            return "DuckDuckGo"
        }
        if host.contains("amazon.com") {
            if let query = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "k" })?.value {
                return "Amazon.com: \(query)"
            }
            return "Amazon.com"
        }
        if host.contains("youtube.com") {
            if let query = URLComponents(string: urlString)?.queryItems?.first(where: { $0.name == "search_query" })?.value {
                return "\(query) - YouTube"
            }
            return "YouTube"
        }

        return "\(host.replacingOccurrences(of: "www.", with: "").capitalized) - News Article"
    }

    /// Return mock JS results that match what modules expect
    static func simulatedJSResult(for script: String) -> String? {
        // document.title
        if script.contains("document.title") && !script.contains("querySelectorAll") {
            return "Mock Page Title"
        }

        // window.location.href
        if script.contains("window.location.href") {
            return "https://www.example.com/mock-page"
        }

        // Search result click — return a mock URL
        if script.contains("organic") || script.contains("#search a[href]") || script.contains("b_algo") {
            return "https://www.example.com/search-result-\(Int.random(in: 1...100))"
        }

        // Amazon product click
        if script.contains("s-search-result") || script.contains("/dp/") {
            return "https://www.amazon.com/dp/B0MOCK\(Int.random(in: 1000...9999))"
        }

        // YouTube video click
        if script.contains("video-title") || script.contains("/watch?v=") {
            return "https://www.youtube.com/watch?v=mock\(Int.random(in: 1000...9999))"
        }

        // Video duration — return a short duration so the mock watch loop finishes quickly.
        // The mock wait() returns in 1ms, so real durations would cause thousands of loop iterations.
        if script.contains("video.duration") || script.contains("video") && script.contains("duration") {
            return "\(Int.random(in: 30...90))" // 0.5-1.5 minutes (short for mock speed)
        }

        // News article click
        if script.contains("article a[href]") || script.contains("headline") || script.contains("h2 a") {
            return "https://www.example.com/article-\(Int.random(in: 1...100))"
        }

        // Related link from article
        if script.contains("article-body") || script.contains("post-content") {
            return "https://www.example.com/related-\(Int.random(in: 1...100))"
        }

        // scrollBy, click, play — no return value expected
        if script.contains("scrollBy") || script.contains(".click()") || script.contains(".play()") {
            return nil
        }

        return nil
    }
}
