import Foundation

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

        let persona = Persona.loadDefault()
        let generator = QueryGenerator(persona: persona)

        // Decide: single query or burst of related queries?
        let doBurst = Double.random(in: 0...1) < 0.4  // 40% chance of burst
        let queries = doBurst ? generator.generateBurst() : [generator.generateQuery()]

        for query in queries {
            guard !shouldStop else { break }

            // Pick a random search engine
            let engine = SearchEngine.allCases.randomElement()!
            let url = engine.searchURL(for: query)

            statusText = "\(engine.rawValue): \(query)"
            ActivityLog.shared.log(module: id, action: "Searching \(engine.rawValue): \(query)")

            // Load the search page
            let loaded = await webView.loadURL(url)
            guard loaded, !shouldStop else { continue }

            // Wait for the page to render (simulates reading time)
            await webView.wait(seconds: Double.random(in: 2...4))

            // Scroll down the search results (simulates scanning)
            await scrollResults(webView: webView)

            // 60% chance: click through to a search result
            if Double.random(in: 0...1) < 0.6 && !shouldStop {
                await clickResult(webView: webView)
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
    private func clickResult(webView: WebViewInstance) async {
        // Try to find organic search result links
        // Google: #search a[href], Bing: .b_algo a, DDG: .result__a
        let clickJS = """
        (function() {
            var links = document.querySelectorAll('#search a[href]:not([href*="google"]), .b_algo a[href], .result__a[href]');
            var organic = Array.from(links).filter(function(a) {
                var href = a.href || '';
                return href.startsWith('http') && !href.includes('google.com') && !href.includes('bing.com') && !href.includes('duckduckgo.com');
            });
            if (organic.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(organic.length, 5));
                organic[idx].click();
                return 'clicked';
            }
            return 'no-results';
        })()
        """

        let result = await webView.executeJS(clickJS)

        if result == "clicked" {
            ActivityLog.shared.log(module: id, action: "Clicked search result")

            // Wait for the result page to load
            await webView.wait(seconds: Double.random(in: 3...8))

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
