import Foundation

// Escape strings for safe interpolation into JavaScript string literals.
// Prevents injection when user-provided data (persona interests, blocked domains)
// gets embedded in JS that runs inside the web view.
extension String {
    var jsEscaped: String {
        var result = self
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "'", with: "\\'")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "`", with: "\\`")          // template literal delimiter
        result = result.replacingOccurrences(of: "${", with: "\\${")        // template expression injection
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\0", with: "\\0")         // null byte truncation
        result = result.replacingOccurrences(of: "</script>", with: "<\\/script>")  // script breakout
        return result
    }
}

// Generates fake search queries on Google, Bing, and DuckDuckGo.
// Simulates a real person researching topics — loads the search page,
// scrolls results, clicks through to a result, waits, then moves on.
class SearchNoiseModule: BrowsingModule {

    let id = "search"
    let displayName = "Search Noise"
    var isEnabled = false
    private(set) var isActive = false
    private(set) var statusText = "Idle"
    private(set) var actionsCompleted = 0
    private var shouldStop = false

    // Which search engines to use
    enum SearchEngine: String, CaseIterable {
        case google = "Google"
        case bing = "Bing"
        case duckduckgo = "DuckDuckGo"

        func searchURL(for query: String) -> String {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            switch self {
            case .google:     return "https://www.google.com/search?q=\(encoded)"
            case .bing:       return "https://www.bing.com/search?q=\(encoded)"
            case .duckduckgo: return "https://duckduckgo.com/?q=\(encoded)"
            }
        }
    }

    func execute(webView: WebViewInstance) async {
        isActive = true
        shouldStop = false
        actionsCompleted = 0

        let settings = SettingsManager.shared.current
        let persona = Persona.loadDefault()
        let generator = QueryGenerator(persona: persona)

        // Decide: single query or burst of related queries?
        let doBurst = settings.searchBurstMode && Double.random(in: 0...1) < 0.4
        let queries = doBurst ? generator.generateBurst() : [generator.generateQuery()]

        // Filter engines based on settings
        let enabledEngines = SearchEngine.allCases.filter { engine in
            settings.enabledSearchEngines.contains(engine.rawValue)
        }
        guard !enabledEngines.isEmpty else {
            isActive = false
            return
        }

        let sessionType = doBurst ? "burst (\(queries.count) queries)" : "single"

        for (queryIndex, query) in queries.enumerated() {
            guard !shouldStop else { break }

            // Pick a random enabled search engine
            let engine = enabledEngines.randomElement()!
            let url = engine.searchURL(for: query)

            statusText = "\(engine.rawValue): \(query)"
            ActivityLog.shared.log(module: id, action: "Search query", metadata: [
                "engine": engine.rawValue,
                "query": query,
                "url": url,
                "sessionType": sessionType,
                "queryIndex": "\(queryIndex + 1)/\(queries.count)",
            ])

            // Load the search page
            let loaded = await webView.loadURL(url)
            guard loaded, !shouldStop else { continue }

            // Wait for the page to render (simulates reading time)
            await webView.wait(seconds: Double.random(in: 2...4))

            // Scroll down the search results (simulates scanning)
            await scrollResults(webView: webView)

            // 60% chance: click through to a search result (if enabled)
            if settings.searchClickThrough && Double.random(in: 0...1) < 0.6 && !shouldStop {
                await clickResult(webView: webView, searchEngine: engine.rawValue, query: query)
            }

            actionsCompleted += 1

            // Delay between queries in a burst (shorter than between sessions)
            if queries.count > 1 {
                await webView.wait(seconds: Double.random(in: 3...8))
            }
        }

        statusText = "Idle"
        isActive = false
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - JS Interactions

    /// Scroll through search results like someone reading them
    private func scrollResults(webView: WebViewInstance) async {
        let scrollSteps = Int.random(in: 2...4)
        for _ in 0..<scrollSteps {
            guard !shouldStop else { return }
            let scrollAmount = Int.random(in: 200...500)
            await webView.runJS("window.scrollBy(0, \(scrollAmount))")
            await webView.wait(seconds: Double.random(in: 0.8...2.0))
        }
    }

    /// Click on a random organic search result and browse the page
    private func clickResult(webView: WebViewInstance, searchEngine: String, query: String) async {
        // Build a JS array of blocked domains to filter out (sanitized to prevent JS injection)
        let blocked = SettingsManager.shared.current.blockedDomains
            .map { "\"\($0.lowercased().trimmingCharacters(in: CharacterSet.whitespaces).jsEscaped)\"" }
            .joined(separator: ",")

        // Try to find organic search result links — returns the href or "no-results"
        let clickJS = """
        (function() {
            var blocked = [\(blocked)];
            var links = document.querySelectorAll('#search a[href]:not([href*="google"]), .b_algo a[href], .result__a[href]');
            var organic = Array.from(links).filter(function(a) {
                var href = a.href || '';
                if (!href.startsWith('http') || href.includes('google.com') || href.includes('bing.com') || href.includes('duckduckgo.com')) return false;
                try {
                    var host = new URL(href).hostname.toLowerCase();
                    for (var b of blocked) { if (host === b || host.endsWith('.' + b)) return false; }
                } catch(e) {}
                return true;
            });
            if (organic.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(organic.length, 5));
                var href = organic[idx].href;
                organic[idx].click();
                return href;
            }
            return 'no-results';
        })()
        """

        let result = await webView.executeJS(clickJS)

        if let clickedUrl = result, clickedUrl != "no-results" {
            // Wait for the result page to load
            await webView.wait(seconds: Double.random(in: 3...8))

            let pageTitle = await webView.pageTitle()

            ActivityLog.shared.log(module: id, action: "Clicked search result", metadata: [
                "engine": searchEngine,
                "query": query,
                "clickedUrl": clickedUrl,
                "pageTitle": pageTitle,
            ])

            // Scroll the result page (simulates reading)
            let scrollSteps = Int.random(in: 2...5)
            for _ in 0..<scrollSteps {
                guard !shouldStop else { return }
                let scrollAmount = Int.random(in: 200...400)
                await webView.runJS("window.scrollBy(0, \(scrollAmount))")
                await webView.wait(seconds: Double.random(in: 1...3))
            }
        }
    }
}
