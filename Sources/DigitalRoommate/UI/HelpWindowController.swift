import Cocoa
import WebKit

// "About Digital Roommate" window.
// Shows a styled HTML page in a WKWebView explaining what the app does,
// how each module works, and how to customize the persona JSON.
// Singleton — calling show() again brings the existing window to front.
class HelpWindowController: NSWindowController {

    static let shared = HelpWindowController()

    private var webView: WKWebView!

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Styles.helpSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Digital Roommate"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        super.init(window: window)

        setupWebView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func show() {
        webView.loadHTMLString(helpHTML(), baseURL: nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView = webView
    }

    // MARK: - HTML Content

    private func helpHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 13px;
                line-height: 1.6;
                color: #1d1d1f;
                padding: 28px 32px;
                background: #ffffff;
                -webkit-font-smoothing: antialiased;
            }
            @media (prefers-color-scheme: dark) {
                body { background: #1e1e1e; color: #f5f5f7; }
                .module-card { background: #2a2a2a; border-color: #3a3a3a; }
                code { background: #2a2a2a; }
                .section-divider { border-color: #3a3a3a; }
            }
            h1 { font-size: 22px; font-weight: 600; margin-bottom: 4px; }
            .subtitle { color: #86868b; font-size: 13px; margin-bottom: 20px; }
            h2 { font-size: 15px; font-weight: 600; margin: 20px 0 8px; }
            p { margin-bottom: 10px; }
            .module-card {
                background: #f5f5f7;
                border: 1px solid #e5e5e5;
                border-radius: 8px;
                padding: 12px 14px;
                margin-bottom: 8px;
            }
            .module-name { font-weight: 600; font-size: 13px; }
            .module-desc { color: #6e6e73; font-size: 12px; margin-top: 2px; }
            code {
                font-family: SF Mono, Menlo, monospace;
                font-size: 11px;
                background: #f5f5f7;
                padding: 2px 6px;
                border-radius: 4px;
            }
            .section-divider {
                border: none;
                border-top: 1px solid #e5e5e5;
                margin: 20px 0;
            }
            ul { padding-left: 20px; margin-bottom: 10px; }
            li { margin-bottom: 4px; }
        </style>
        </head>
        <body>
            <h1>Digital Roommate</h1>
            <p class="subtitle">Privacy noise generator for macOS</p>

            <p>Digital Roommate creates realistic web traffic from a fake persona, making it look like
            another person lives in your house. This poisons ISP-level and data-broker profiling by
            mixing your real browsing with convincing decoy activity.</p>

            <hr class="section-divider">

            <h2>How It Works</h2>
            <p>The app runs hidden browser sessions in the background using time-aware scheduling.
            Activity levels vary throughout the day just like a real person \u{2014} more active in the
            afternoon, quieter late at night.</p>

            <hr class="section-divider">

            <h2>Modules</h2>

            <div class="module-card">
                <div class="module-name">\u{1F50D} Search Noise</div>
                <div class="module-desc">Runs searches on Google, Bing, and DuckDuckGo using your persona's
                interests. Sometimes does multi-query research bursts. Clicks through to results to
                create realistic browsing trails.</div>
            </div>

            <div class="module-card">
                <div class="module-name">\u{1F6D2} Shopping Noise</div>
                <div class="module-desc">Browses Amazon \u{2014} searches for products, views product pages,
                scrolls through images and reviews. Creates the impression of an active online shopper.</div>
            </div>

            <div class="module-card">
                <div class="module-name">\u{25B6}\u{FE0F} Video Noise</div>
                <div class="module-desc">Watches YouTube videos from your persona's interests. Plays muted,
                watches variable durations (30\u{2013}90% of each video), and skips ads automatically.</div>
            </div>

            <div class="module-card">
                <div class="module-name">\u{1F4F0} News & Browsing</div>
                <div class="module-desc">Visits news sites, reads articles at realistic speed, and occasionally
                follows related links. Covers general, tech, hobby, and professional sites.</div>
            </div>

            <hr class="section-divider">

            <h2>Customizing the Persona</h2>
            <p>The fake persona (name, interests, shopping habits, video topics) defines
            what kind of person your traffic looks like. To customize it:</p>
            <ul>
                <li>Open <strong>Settings &rarr; Persona</strong></li>
                <li>Edit the name, interests, search topics, shopping terms, and video queries</li>
                <li>Click <strong>Save Changes</strong> \u{2014} takes effect on the next browsing session</li>
            </ul>
            <p>Use <strong>Settings &rarr; Sites &amp; Privacy</strong> to see which sites the roommate visits and block specific domains.</p>

            <hr class="section-divider">

            <h2>Settings</h2>
            <p>Use <strong>Settings</strong> (in the menu bar dropdown) to control activity level,
            active time blocks, and per-module options like which search engines to use, video
            watch duration, and more.</p>

            <hr class="section-divider">

            <p style="color: #86868b; font-size: 11px; margin-top: 16px;">
                Digital Roommate \u{2014} Your data is your own.
            </p>
        </body>
        </html>
        """
    }
}
