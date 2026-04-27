<p align="center">
  <img src="assets/app-icon.png" width="128" height="128" alt="Digital Roommate app icon">
</p>
<h1 align="center">Digital Roommate</h1>
<p align="center">A privacy experiment: generates synthetic browsing traffic to reduce the precision of data-broker and ISP-level profiling. macOS.</p>
<p align="center"><strong>v1.0</strong> · macOS 14+ · Apple Silicon & Intel</p>
<p align="center"><a href="https://github.com/madebysan/digital-roommate/releases/latest"><strong>Download Digital Roommate</strong></a></p>

---

<p align="center">
  <img src="assets/screenshot.png" width="720" alt="Digital Roommate menu bar dropdown, active persona, and persona JSON">
</p>

---

Most privacy tools try to minimize what leaks. Digital Roommate is an experiment in the opposite direction. It generates extra traffic from a fake roommate's browsing pattern, so the signal about you is harder to isolate among the noise. The intent is to reduce how precisely a third party can profile you on your end, not to interfere with anyone's systems. Effective against bulk ISP-level and data-broker profiling. Not effective against targeted TLS fingerprinting, website-level bot detection, or anything that looks at device fingerprints.

## What it doesn't do

- Won't fool Google reCAPTCHA or Amazon's bot detection
- Won't bypass CAPTCHAs or create accounts
- Won't touch your personal browsing or cookies
- Won't send any data to any server. Traffic is outbound-only to public sites.

## Modules

Four modules run in the background, each covering a different slice of normal browsing.

| Module | What it does |
|--------|-------------|
| **Search Noise** | Runs searches on Google, Bing, and DuckDuckGo using the persona's interests. Occasional multi-query research bursts. Clicks through to results so there's a realistic trail. |
| **Shopping Noise** | Browses Amazon. Searches, views product pages, scrolls through images and reviews. |
| **Video Noise** | Watches YouTube videos from the persona's interests. Muted, variable durations (30–90% of each video), skips ads automatically. |
| **News & Browsing** | Visits news sites, reads articles at realistic speed, occasionally follows related links. General, tech, hobby, and professional sites. |

Every module reads from the same persona. A JSON file with interests, profession, shopping habits, and a schedule.

## How it works

### Traffic generation

- **Offscreen WKWebViews.** Real WebKit engine with JavaScript and cookie persistence. Web views sit offscreen between actions instead of being destroyed, so sites see normal browser behavior. Pool capped at 3 concurrent views by default.
- **Isolated cookie stores.** Each module gets its own persistent `WKWebsiteDataStore` keyed by module ID. The search persona and shopping persona don't leak into each other, and neither touches your personal browser.
- **Anti-detection JS.** Overrides `navigator.webdriver` to `undefined`, fills plugin and MIME-type arrays, and spoofs the Page Visibility API so background tabs (YouTube) don't pause. WebGL fingerprint normalization is implemented but disabled. On Apple Silicon it was creating a *more* unique fingerprint than the default.

### Scheduling

- **Poisson-distributed timing.** Inter-activity delays use an exponential distribution (`-ln(U) × mean`), so the spacing is irregular like real browsing instead of on a fixed interval.
- **Time-of-day weighting.** Activity probability varies by time block (morning, afternoon, evening, late night). Includes a "Vampire mode" weight for occasional 2–5 AM activity.
- **Weekend / weekday split.** Weekends use different multipliers: later mornings, shifted peaks.

### Hardening

- **Safari-only user agents.** Each new WebView gets a random Safari UA (17.3–18.3 on Sonoma / Sequoia). Safari UAs because WKWebView's TLS ClientHello (JA3 / JA4) matches Safari / WebKit. Faking a Chrome or Firefox UA would create an obvious TLS-to-UA mismatch any fingerprinting middlebox would catch.
- **HTTPS-only.** App Transport Security is enforced. No plaintext HTTP traffic that would expose URL paths to passive observers.
- **URL scheme allowlist.** Only `http` and `https` are permitted. `file://`, `javascript:`, and `data:` URLs get rejected at the WebView level before loading.
- **Blocked-domain enforcement.** Checked in all four modules before navigation *and* in the WebView's `decidePolicyFor` delegate as a safety net. Double-layered.
- **JS injection escaping.** User-provided strings (persona interests, blocked domains) that get injected into WebView JavaScript are escaped for backticks, `${}` template expressions, null bytes, and `</script>` breakout sequences.
- **Thread-safe logging.** Activity-log writes go through a dedicated `DispatchQueue` to prevent data races when multiple modules run concurrently. Console output is compiled out in release builds (`#if DEBUG`).

## Known limitations

### TLS fingerprinting

WKWebView's TLS ClientHello has a known JA3 / JA4 fingerprint that matches Safari / WebKit. The app uses Safari-only UAs to keep TLS-to-UA consistent, but an observer doing active TLS fingerprint analysis (not just passive hostname logging) can identify all WKWebView traffic as coming from the same engine. Effective against bulk profiling. Not effective against targeted TLS inspection.

### DNS visibility

All hostname lookups are standard plaintext DNS visible to your ISP. Even with HTTPS, every hostname resolved is exposed. If DNS privacy matters, set up system-level DNS-over-HTTPS via [NextDNS](https://nextdns.io), [Cloudflare WARP](https://1.1.1.1), or a macOS DoH profile.

### Sandbox

The app runs without macOS App Sandbox (`com.apple.security.app-sandbox = false`). Required for WKWebView to run with isolated data stores and custom configurations. WKWebView's own multi-process architecture gives process-level isolation for web content, but a WebKit exploit would have a bigger attack surface than in a sandboxed app.

## Installation

### From DMG (recommended)

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Digital Roommate** to Applications
3. Launch from Applications. It lives in the menu bar, not the Dock.

### From source

```bash
git clone https://github.com/madebysan/digital-roommate.git
cd digital-roommate
swift build -c release
# Binary at .build/release/DigitalRoommate
```

## Usage

First launch walks through a 5-step onboarding: Welcome → Modules → Activity level → Persona → Summary. Nothing starts until you click "Get Started."

After that, click the person icon in the menu bar to see module status and current activity, toggle modules on / off, pause or resume everything, enable Launch at Login, or open the activity log.

### Settings

Sidebar with 7 sections.

| Section | What you configure |
|---------|-------------------|
| **General** | Activity level, active time blocks, max concurrent browsers, launch at login |
| **Search** | Search engine toggles (Google, Bing, DuckDuckGo), burst mode, click-through |
| **Shopping** | Products per session, image browsing, review scrolling |
| **Video** | Max watch duration, ad skipping, mute |
| **News** | Articles per session, sites per session, follow related links |
| **Sites & Privacy** | Visited sites list, blocked domains |
| **Persona** | Active persona picker, randomize, export, reset, edit interests / topics / categories |

### Choose your noise level

| Level | Sessions/hour | Character |
|-------|--------------|-----------|
| **Low** | ~2–3 | Minimal bandwidth. Quiet roommate. |
| **Medium** | ~5–8 | Moderate presence. Good starting point. |
| **High** | ~10–15 | Heavy traffic, heavy browser. |

Timing follows a Poisson distribution: more active in the afternoon and evening, quieter at night, different patterns on weekends.

### Persona

Personas live in `~/Library/Application Support/DigitalRoommate/personas/` and define search topics, shopping categories, video interests, news sites, and active-hours weights for each time block. Manage from Settings → Persona: switch between personas, randomize, export as JSON, or edit interests inline.

### Activity log

JSON at `~/Library/Application Support/DigitalRoommate/activity-log.json`. Records what each module did and when.

## Architecture

<details>
<summary>File tree</summary>

```
Sources/DigitalRoommate/
├── main.swift                    # Entry point
├── AppDelegate.swift             # Lifecycle, App Nap prevention
├── Core/
│   ├── BrowsingEngine.swift      # Offscreen WKWebView pool
│   ├── WebViewInstance.swift     # WKWebView wrapper, URL/scheme validation
│   ├── Scheduler.swift           # Poisson-distributed, time-aware scheduling
│   ├── ModuleRegistry.swift      # Module lifecycle management
│   └── BrowsingModule.swift      # Protocol for all modules
├── Modules/
│   ├── SearchNoiseModule.swift   # Google/Bing/DDG search + click-through
│   ├── ShoppingNoiseModule.swift # Amazon browsing
│   ├── VideoNoiseModule.swift    # YouTube watching, ad skip, watch history
│   └── NewsModule.swift          # News reading, link following
├── Persona/
│   ├── Persona.swift             # Codable model + multi-persona storage
│   ├── PersonaGenerator.swift    # Random persona generation
│   ├── PersonaSchedule.swift     # Time-based activity weighting
│   └── QueryGenerator.swift      # Template-based search queries
├── Settings/
│   ├── AppSettings.swift         # User-configurable settings (Codable)
│   └── SettingsManager.swift     # Singleton persistence (UserDefaults)
├── UI/
│   ├── Styles.swift              # Design tokens, card builders
│   ├── StatusBarController.swift # Menu bar icon and dropdown
│   ├── SettingsWindowController.swift  # Sidebar settings
│   ├── OnboardingWindowController.swift # 5-step onboarding
│   └── HelpWindowController.swift      # About window
├── Persistence/
│   └── StateStore.swift          # JSON state + thread-safe activity log
├── Testing/
│   ├── TestRunner.swift          # Test framework
│   ├── TestConfig.swift          # Test configuration
│   ├── TestPersonas.swift        # Test fixtures
│   └── MockWebViewInstance.swift # WKWebView mock
└── AntiDetection/
    ├── UserAgentProvider.swift   # Safari UA rotation (17.3–18.3)
    └── StealthScripts.swift      # Navigator + visibility spoofing
```

</details>

## Privacy

Nothing leaves your Mac except normal-looking outbound web traffic to public sites. All browsing runs in isolated WKWebViews so your personal cookies and history stay untouched. Activity log stays local. No analytics, no telemetry, no phone-home. Zero third-party dependencies, Apple frameworks only.

## Requirements

- macOS 14.0 (Sonoma) or later
- No external dependencies

## License

[MIT](LICENSE)

---

Made by [santiagoalonso.com](https://santiagoalonso.com)
