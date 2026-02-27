import Foundation

// Provides realistic user agent strings that rotate per session.
// Loaded from a bundled JSON file with common desktop browser UAs.
class UserAgentProvider {

    static let shared = UserAgentProvider()

    private var userAgents: [String] = []

    private init() {
        loadUserAgents()
    }

    /// Get a random user agent string
    func randomUserAgent() -> String {
        return userAgents.randomElement() ?? Self.fallbackUA
    }

    private func loadUserAgents() {
        // Try bundled resource
        if let url = Bundle.main.url(forResource: "user-agents", withExtension: "json", subdirectory: "Resources"),
           let data = try? Data(contentsOf: url),
           let agents = try? JSONDecoder().decode([String].self, from: data),
           !agents.isEmpty {
            userAgents = agents
            return
        }

        // Fallback to hardcoded list of common desktop UAs
        userAgents = Self.builtinUserAgents
    }

    // Safari user agent — our primary fallback
    private static let fallbackUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"

    // Safari-only macOS user agents.
    //
    // WKWebView's TLS ClientHello fingerprint (JA3/JA4) is WebKit-based.
    // Claiming to be Chrome/Firefox/Edge while fingerprinting as WebKit
    // makes the traffic trivially identifiable to any ISP doing TLS
    // fingerprinting. Safari's TLS fingerprint is the closest match to
    // WKWebView's, so Safari-only UAs are the most consistent choice.
    //
    // Covers Safari 17.x-18.x across macOS Sonoma and Sequoia.
    private static let builtinUserAgents = [
        // Safari 18.x on macOS Sequoia (2024-2025)
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_1_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
        // Safari 18.x on macOS Sonoma (2024-2025)
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
        // Safari 17.x on macOS Sonoma (2023-2024)
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15",
    ]
}
