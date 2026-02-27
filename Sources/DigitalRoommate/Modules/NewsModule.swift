import Foundation

// Browses news sites, reads articles, and follows links — simulating
// a person's daily news reading habits. Covers general news, tech news,
// professional/industry sites, and hobby-related content.
class NewsModule: BrowsingModule {

    let id = "news"
    let displayName = "News & Browsing"
    var isEnabled = false
    private(set) var isActive = false
    private(set) var statusText = "Idle"
    private(set) var actionsCompleted = 0
    private var shouldStop = false

    private var settings: AppSettings { SettingsManager.shared.current }

    func execute(webView: WebViewInstance) async {
        isActive = true
        shouldStop = false
        actionsCompleted = 0

        // Build site list from settings (user-editable) with persona as fallback
        let siteUrls = settings.browsingSites
        guard !siteUrls.isEmpty else {
            isActive = false
            return
        }

        // Convert URLs to NewsSite structs (derive name from hostname)
        let allSites: [Persona.NewsSite] = siteUrls.compactMap { urlString in
            guard let url = URL(string: urlString), let host = url.host else { return nil }
            let name = host.replacingOccurrences(of: "www.", with: "").capitalized
            return Persona.NewsSite(name: name, url: urlString, category: "custom")
        }

        // Pick sites to visit this session (count from settings)
        let maxSites = settings.newsSitesPerSession
        let sitesToVisit = min(Int.random(in: 1...max(1, maxSites)), allSites.count)
        let sites = allSites.shuffled().prefix(sitesToVisit)

        for site in sites {
            guard !shouldStop else { break }
            // Skip blocked domains
            if settings.isDomainBlocked(site.url) {
                ActivityLog.shared.log(module: id, action: "Skipped blocked site", metadata: [
                    "siteName": site.name, "siteUrl": site.url,
                ])
                continue
            }
            await browseSite(webView: webView, site: site)
        }

        statusText = "Idle"
        isActive = false
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - Browsing Behaviors

    /// Visit a news site: load homepage, read articles, follow links
    private func browseSite(webView: WebViewInstance, site: Persona.NewsSite) async {
        statusText = "Reading: \(site.name)"
        ActivityLog.shared.log(module: id, action: "Visiting news site", metadata: [
            "siteName": site.name,
            "siteUrl": site.url,
            "category": site.category,
        ])

        // Load the homepage
        let loaded = await webView.loadURL(site.url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))

        // Scroll through the homepage (scanning headlines)
        await scrollPage(webView: webView, steps: Int.random(in: 3...6))
        actionsCompleted += 1

        // Click on articles (count from settings)
        let maxArticles = settings.newsArticlesPerSession
        let articlesToRead = Int.random(in: 1...max(1, maxArticles))
        for i in 0..<articlesToRead {
            guard !shouldStop else { return }

            // Find and click an article link
            let clickJS = """
            (function() {
                // Common article link patterns across news sites
                var selectors = [
                    'article a[href]',
                    '.story-card a[href]',
                    '.post-card a[href]',
                    'h2 a[href]',
                    'h3 a[href]',
                    '.headline a[href]',
                    '.listing a[href]',
                    'main a[href]'
                ];

                var allLinks = [];
                for (var s of selectors) {
                    var found = document.querySelectorAll(s);
                    for (var a of found) {
                        if (a.href && a.href.startsWith('http') && a.textContent.trim().length > 10) {
                            allLinks.push(a);
                        }
                    }
                }

                // Deduplicate by href
                var seen = new Set();
                var unique = allLinks.filter(function(a) {
                    if (seen.has(a.href)) return false;
                    seen.add(a.href);
                    return true;
                });

                if (unique.length > \(i)) {
                    var idx = Math.min(\(i) + Math.floor(Math.random() * 3), unique.length - 1);
                    var href = unique[idx].href;
                    unique[idx].click();
                    return href;
                }
                return 'none';
            })()
            """

            let result = await webView.executeJS(clickJS)
            if let articleUrl = result, articleUrl != "none" {
                // Wait for article to load
                await webView.wait(seconds: Double.random(in: 2...4))

                let title = await webView.pageTitle()
                let currentUrl = await webView.executeJS("window.location.href") ?? articleUrl
                statusText = "Reading: \(String(title.prefix(40)))"
                ActivityLog.shared.log(module: id, action: "Reading article", metadata: [
                    "articleTitle": title,
                    "articleUrl": currentUrl,
                    "siteName": site.name,
                    "articleIndex": "\(i + 1)/\(articlesToRead)",
                ])

                // Read the article (scroll at reading speed)
                await readArticle(webView: webView)
                actionsCompleted += 1

                // 30% chance: follow a link from the article (if enabled)
                if settings.newsFollowRelatedLinks && Double.random(in: 0...1) < 0.3 && !shouldStop {
                    await followRelatedLink(webView: webView)
                }

                // Go back to the homepage for next article
                if i < articlesToRead - 1 {
                    await webView.runJS("window.history.back()")
                    await webView.wait(seconds: Double.random(in: 1...3))
                }
            }
        }
    }

    /// Scroll through an article at reading speed (slower than scanning)
    private func readArticle(webView: WebViewInstance) async {
        let paragraphs = Int.random(in: 4...8)
        for _ in 0..<paragraphs {
            guard !shouldStop else { return }
            // Smaller scrolls, longer pauses = reading behavior
            let scrollAmount = Int.random(in: 150...350)
            await webView.runJS("window.scrollBy(0, \(scrollAmount))")
            await webView.wait(seconds: Double.random(in: 2...5))
        }
    }

    /// Follow a related link from within an article (1 hop deep)
    private func followRelatedLink(webView: WebViewInstance) async {
        // Build blocked domains array for JS filtering
        let blocked = settings.blockedDomains
            .map { "\"\($0.lowercased().trimmingCharacters(in: .whitespaces).jsEscaped)\"" }
            .joined(separator: ",")

        let clickJS = """
        (function() {
            var blocked = [\(blocked)];
            // Find in-article links (not nav, not social, not ads)
            var articleBody = document.querySelector('article, .article-body, .post-content, main');
            if (!articleBody) return 'none';

            var links = articleBody.querySelectorAll('a[href]');
            var valid = Array.from(links).filter(function(a) {
                var href = a.href || '';
                var text = a.textContent.trim();
                if (!href.startsWith('http') || text.length <= 5 || href.includes('#')) return false;
                if (href.includes('twitter.com') || href.includes('facebook.com') || href.includes('instagram.com')) return false;
                try {
                    var host = new URL(href).hostname.toLowerCase();
                    for (var b of blocked) { if (host === b || host.endsWith('.' + b)) return false; }
                } catch(e) {}
                return true;
            });

            if (valid.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(valid.length, 5));
                var href = valid[idx].href;
                valid[idx].click();
                return href;
            }
            return 'none';
        })()
        """

        let result = await webView.executeJS(clickJS)
        if let linkUrl = result, linkUrl != "none" {
            await webView.wait(seconds: Double.random(in: 2...4))

            let title = await webView.pageTitle()
            let currentUrl = await webView.executeJS("window.location.href") ?? linkUrl
            ActivityLog.shared.log(module: id, action: "Followed related link", metadata: [
                "pageTitle": title,
                "url": currentUrl,
                "fromUrl": linkUrl,
            ])

            // Briefly scroll through the linked page
            await scrollPage(webView: webView, steps: Int.random(in: 2...4))
            actionsCompleted += 1

            // Go back
            await webView.runJS("window.history.back()")
            await webView.wait(seconds: Double.random(in: 1...2))
        }
    }

    /// General page scrolling (faster than reading)
    private func scrollPage(webView: WebViewInstance, steps: Int) async {
        for _ in 0..<steps {
            guard !shouldStop else { return }
            let scrollAmount = Int.random(in: 200...500)
            await webView.runJS("window.scrollBy(0, \(scrollAmount))")
            await webView.wait(seconds: Double.random(in: 0.8...2.0))
        }
    }
}
