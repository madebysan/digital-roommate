# Digital Roommate — Decision Log

## 1. Consolidated 5 products into 1 app
Search noise, shopping noise, video noise, and roommate core merged into a single macOS menu bar app. Price Check stays a separate Chrome extension. Rationale: shared infrastructure (scheduling, persona management, WKWebView pool, state persistence) makes separate apps wasteful.

## 2. Pure Swift + AppKit + WKWebView, no Python/Playwright
WKWebView provides a real WebKit browser engine with JS injection, cookie persistence, and custom UA. No external dependencies. Trades Playwright's mouse simulation for simplicity and a clean .app bundle. Rationale: primary goal is network-level pattern of life (ISP/data broker), not fooling website-level bot detection. Both generate identical network traffic.

## 3. Network-level obfuscation is the primary goal
Not trying to fool Amazon's TLS fingerprinting or Google's reCAPTCHA. Trying to make the household's aggregate traffic look like multiple people live here. ISPs see DNS queries, connection metadata, traffic volume, and timing — none of which depend on the browser engine.

## 4. Price Check stays a separate Chrome extension
UA spoofing needs to happen in the user's actual Chrome browsing session. A WKWebView built-in browser would mean shopping outside Chrome, which changes the workflow too much.

## 5. macOS 14+ minimum deployment target
Required for `WKWebsiteDataStore(forIdentifier:)` which gives each module its own isolated persistent cookie store. Without this, all modules share cookies, which defeats the purpose of separate browsing profiles.

## 6. Offscreen window at (-10000, -10000), not hidden/ordered-out
macOS App Nap aggressively throttles hidden windows. Positioning offscreen avoids this while keeping the window "visible" to the system. Combined with `ProcessInfo.processInfo.beginActivity()` for belt-and-suspenders.

## 7. No WKScriptMessageHandler registration
All interaction driven from Swift via `evaluateJavaScript`. Avoids exposing `window.webkit.messageHandlers` which is a WKWebView detection vector that sites can check.

## 8. ~~Shared WKProcessPool~~ — Removed
WKProcessPool was deprecated in macOS 12 and creating multiple instances has no effect. Removed the shared pool; each WKWebView uses the default process pool automatically.
