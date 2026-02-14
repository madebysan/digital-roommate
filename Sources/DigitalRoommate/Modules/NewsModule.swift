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

    func execute(webView: WebViewInstance) async {
        isActive = true
        shouldStop = false
        actionsCompleted = 0

        let persona = Persona.loadDefault()
        guard !persona.newsSites.isEmpty else {
            isActive = false
            return
        }

        // Pick 1-2 sites to visit this session
        let sitesToVisit = min(Int.random(in: 1...2), persona.newsSites.count)
        let sites = persona.newsSites.shuffled().prefix(sitesToVisit)

        for site in sites {
            guard !shouldStop else { break }
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
        ActivityLog.shared.log(module: id, action: "Visiting \(site.name) (\(site.url))")

        // Load the homepage
        let loaded = await webView.loadURL(site.url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))

        // Scroll through the homepage (scanning headlines)
        await scrollPage(webView: webView, steps: Int.random(in: 3...6))
        actionsCompleted += 1

        // Click on 1-3 articles
        let articlesToRead = Int.random(in: 1...3)
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
                    unique[idx].click();
                    return 'clicked';
                }
                return 'none';
            })()
            """

            let result = await webView.executeJS(clickJS)
            if result == "clicked" {
                // Wait for article to load
                await webView.wait(seconds: Double.random(in: 2...4))

                let title = await webView.pageTitle()
                statusText = "Reading: \(String(title.prefix(40)))"
                ActivityLog.shared.log(module: id, action: "Reading: \(title)")

                // Read the article (scroll at reading speed)
                await readArticle(webView: webView)
                actionsCompleted += 1

                // 30% chance: follow a link from the article (1 hop)
                if Double.random(in: 0...1) < 0.3 && !shouldStop {
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
        let clickJS = """
        (function() {
            // Find in-article links (not nav, not social, not ads)
            var articleBody = document.querySelector('article, .article-body, .post-content, main');
            if (!articleBody) return 'none';

            var links = articleBody.querySelectorAll('a[href]');
            var valid = Array.from(links).filter(function(a) {
                var href = a.href || '';
                var text = a.textContent.trim();
                return href.startsWith('http') &&
                       text.length > 5 &&
                       !href.includes('twitter.com') &&
                       !href.includes('facebook.com') &&
                       !href.includes('instagram.com') &&
                       !href.includes('#');
            });

            if (valid.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(valid.length, 5));
                valid[idx].click();
                return 'clicked';
            }
            return 'none';
        })()
        """

        let result = await webView.executeJS(clickJS)
        if result == "clicked" {
            await webView.wait(seconds: Double.random(in: 2...4))

            let title = await webView.pageTitle()
            ActivityLog.shared.log(module: id, action: "Followed link: \(title)")

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
