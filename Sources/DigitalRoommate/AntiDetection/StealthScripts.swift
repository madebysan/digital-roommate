import Foundation

// JavaScript injected at .atDocumentStart to make WKWebView less detectable.
// These scripts normalize browser properties that sites check to identify
// automated browsers. We're not trying to fool sophisticated bot detection
// (not our goal) — just making the traffic look like a normal browser session.
struct StealthScripts {

    /// All stealth scripts combined, injected before any page JS runs
    static let allScripts: [String] = [
        navigatorOverrides,
        pageVisibilitySpoof,
        webGLNormalization
    ]

    // Override navigator.webdriver (set to undefined in normal browsers)
    // and normalize plugin/mimeType arrays to look like a real browser
    static let navigatorOverrides = """
    (function() {
        // navigator.webdriver is true in automated browsers — make it undefined
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
            configurable: true
        });

        // Normal Chrome reports 5 plugins — empty array is suspicious
        Object.defineProperty(navigator, 'plugins', {
            get: () => {
                return {
                    length: 5,
                    item: function(i) { return null; },
                    namedItem: function(n) { return null; },
                    refresh: function() {},
                    [Symbol.iterator]: function*() {}
                };
            },
            configurable: true
        });

        // Normal browsers report at least 2 MIME types
        Object.defineProperty(navigator, 'mimeTypes', {
            get: () => {
                return {
                    length: 2,
                    item: function(i) { return null; },
                    namedItem: function(n) { return null; },
                    [Symbol.iterator]: function*() {}
                };
            },
            configurable: true
        });

        // Set languages to match a real browser
        Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en'],
            configurable: true
        });

        // Report a reasonable hardware concurrency
        Object.defineProperty(navigator, 'hardwareConcurrency', {
            get: () => 8,
            configurable: true
        });

        // Report reasonable device memory
        Object.defineProperty(navigator, 'deviceMemory', {
            get: () => 8,
            configurable: true
        });
    })();
    """

    // Spoof the Page Visibility API so sites think the tab is always visible.
    // YouTube pauses videos in hidden tabs — this prevents that.
    static let pageVisibilitySpoof = """
    (function() {
        Object.defineProperty(document, 'hidden', {
            get: () => false,
            configurable: true
        });
        Object.defineProperty(document, 'visibilityState', {
            get: () => 'visible',
            configurable: true
        });
        // Suppress visibilitychange events
        const origAddEventListener = document.addEventListener.bind(document);
        document.addEventListener = function(type, listener, options) {
            if (type === 'visibilitychange') return;
            return origAddEventListener(type, listener, options);
        };
    })();
    """

    // Normalize WebGL renderer info (some sites fingerprint GPU info)
    static let webGLNormalization = """
    (function() {
        const origGetParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(param) {
            // UNMASKED_VENDOR_WEBGL
            if (param === 0x9245) return 'Intel Inc.';
            // UNMASKED_RENDERER_WEBGL
            if (param === 0x9246) return 'Intel Iris OpenGL Engine';
            return origGetParameter.call(this, param);
        };

        if (typeof WebGL2RenderingContext !== 'undefined') {
            const origGetParameter2 = WebGL2RenderingContext.prototype.getParameter;
            WebGL2RenderingContext.prototype.getParameter = function(param) {
                if (param === 0x9245) return 'Intel Inc.';
                if (param === 0x9246) return 'Intel Iris OpenGL Engine';
                return origGetParameter2.call(this, param);
            };
        }
    })();
    """
}
