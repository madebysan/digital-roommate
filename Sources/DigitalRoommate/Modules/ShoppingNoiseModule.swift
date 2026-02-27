import Foundation

// Browses Amazon as a fake shopping persona — searches for products,
// views product pages, scrolls through images and details.
// Creates the impression of someone actively shopping online.
class ShoppingNoiseModule: BrowsingModule {

    let id = "shopping"
    let displayName = "Shopping Noise"
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

        let persona = Persona.loadDefault()
        guard !persona.shoppingCategories.isEmpty else {
            isActive = false
            return
        }

        // Pick a random shopping category for this session
        let category = persona.shoppingCategories.randomElement()!

        // Filter product URLs through the blocked domains list
        let allowedProductUrls = category.productUrls.filter { !settings.isDomainBlocked($0) }

        // Decide session type: search-based or direct product URL
        if !allowedProductUrls.isEmpty && Double.random(in: 0...1) < 0.3 {
            // 30% chance: go directly to a product page
            await browseProductPage(webView: webView, url: allowedProductUrls.randomElement()!)
        } else if !settings.isDomainBlocked("https://www.amazon.com") {
            // 70% chance: search Amazon and browse results
            await searchAndBrowse(webView: webView, category: category)
        }

        statusText = "Idle"
        isActive = false
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - Shopping Behaviors

    /// Search Amazon for a product term and browse the results
    private func searchAndBrowse(webView: WebViewInstance, category: Persona.ShoppingCategory) async {
        let searchTerm = category.searchTerms.randomElement() ?? category.name
        let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
        let url = "https://www.amazon.com/s?k=\(encoded)"

        statusText = "Searching: \(searchTerm)"
        ActivityLog.shared.log(module: id, action: "Amazon search", metadata: [
            "searchTerm": searchTerm,
            "category": category.name,
            "url": url,
            "sessionType": "search",
        ])

        let loaded = await webView.loadURL(url)
        guard loaded, !shouldStop else { return }

        // Wait for page to load
        await webView.wait(seconds: Double.random(in: 2...4))

        // Scroll through search results
        await scrollSearchResults(webView: webView)
        actionsCompleted += 1

        // Click on products from results (count from settings)
        let maxProducts = settings.shoppingProductsPerSession
        let productsToView = Int.random(in: 1...max(1, maxProducts))
        for i in 0..<productsToView {
            guard !shouldStop else { return }

            // Click a product link from search results — returns href or "no-products"
            let clickJS = """
            (function() {
                var products = document.querySelectorAll('[data-component-type="s-search-result"] h2 a, .s-result-item h2 a');
                var valid = Array.from(products).filter(function(a) { return a.href && a.href.includes('/dp/'); });
                if (valid.length > \(i)) {
                    var idx = Math.min(\(i) + Math.floor(Math.random() * 3), valid.length - 1);
                    var href = valid[idx].href;
                    valid[idx].click();
                    return href;
                }
                return 'no-products';
            })()
            """

            let result = await webView.executeJS(clickJS)
            if let productUrl = result, productUrl != "no-products" {
                await webView.wait(seconds: Double.random(in: 2...4))
                await browseProductDetails(webView: webView, fromSearch: searchTerm, productUrl: productUrl, productIndex: i + 1, totalProducts: productsToView)
                actionsCompleted += 1

                // Go back to search results for next product
                if i < productsToView - 1 {
                    await webView.runJS("window.history.back()")
                    await webView.wait(seconds: Double.random(in: 2...3))
                }
            }
        }
    }

    /// Browse a product page directly
    private func browseProductPage(webView: WebViewInstance, url: String) async {
        statusText = "Viewing product"
        ActivityLog.shared.log(module: id, action: "Direct product page", metadata: [
            "url": url,
            "sessionType": "direct",
        ])

        let loaded = await webView.loadURL(url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))
        await browseProductDetails(webView: webView, fromSearch: nil, productUrl: url, productIndex: 1, totalProducts: 1)
        actionsCompleted += 1
    }

    /// Simulate browsing a product page — scroll, view images, read reviews
    private func browseProductDetails(webView: WebViewInstance, fromSearch: String?, productUrl: String, productIndex: Int, totalProducts: Int) async {
        let title = await webView.pageTitle()
        let currentUrl = await webView.executeJS("window.location.href") ?? productUrl
        statusText = "Viewing: \(String(title.prefix(40)))"

        var meta: [String: String] = [
            "productTitle": title,
            "url": currentUrl,
            "productIndex": "\(productIndex)/\(totalProducts)",
        ]
        if let search = fromSearch { meta["searchTerm"] = search }

        ActivityLog.shared.log(module: id, action: "Viewing product", metadata: meta)

        // Scroll down slowly (reading product details)
        for _ in 0..<Int.random(in: 3...6) {
            guard !shouldStop else { return }
            let scrollAmount = Int.random(in: 200...500)
            await webView.runJS("window.scrollBy(0, \(scrollAmount))")
            await webView.wait(seconds: Double.random(in: 1...3))
        }

        // 50% chance: click through product images (if enabled)
        if settings.shoppingBrowseImages && Double.random(in: 0...1) < 0.5 && !shouldStop {
            await webView.runJS("""
                var imgThumbs = document.querySelectorAll('#altImages img, .imageThumbnail img');
                if (imgThumbs.length > 1) {
                    var idx = Math.floor(Math.random() * Math.min(imgThumbs.length, 4)) + 1;
                    imgThumbs[Math.min(idx, imgThumbs.length - 1)].click();
                }
            """)
            await webView.wait(seconds: Double.random(in: 1...2))
        }

        // 30% chance: scroll to reviews section (if enabled)
        if settings.shoppingScrollToReviews && Double.random(in: 0...1) < 0.3 && !shouldStop {
            await webView.runJS("""
                var reviewSection = document.getElementById('customerReviews') || document.getElementById('reviews-medley-footer');
                if (reviewSection) reviewSection.scrollIntoView({behavior: 'smooth'});
            """)
            await webView.wait(seconds: Double.random(in: 2...5))
        }
    }

    /// Scroll through Amazon search results
    private func scrollSearchResults(webView: WebViewInstance) async {
        for _ in 0..<Int.random(in: 3...5) {
            guard !shouldStop else { return }
            let scrollAmount = Int.random(in: 300...600)
            await webView.runJS("window.scrollBy(0, \(scrollAmount))")
            await webView.wait(seconds: Double.random(in: 1...2.5))
        }
    }
}
