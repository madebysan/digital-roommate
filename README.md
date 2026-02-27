# Digital Roommate

A macOS menu bar app that generates realistic web traffic from a fake persona — poisoning ISP-level and data-broker profiling of your household.

## What It Does

Digital Roommate creates a "pattern of life" for a fictional person who shares your network. Your ISP and data brokers see traffic that looks like another person lives in your house, with different interests, different browsing habits, and different schedules.

The app runs 4 browsing modules in hidden web views:

| Module | What It Does |
|--------|-------------|
| **Search Noise** | Generates fake searches on Google, Bing, and DuckDuckGo. Clicks through to results. |
| **Shopping Noise** | Browses Amazon — searches products, views listings, scrolls through images and reviews. |
| **Video Noise** | Plays muted YouTube videos, watches for realistic durations, skips ads. |
| **News & Browsing** | Reads articles on news sites, follows links, browses professional and hobby content. |

All traffic is driven by a configurable persona — a JSON file that defines the roommate's interests, profession, shopping habits, and schedule.

## How It Works

**Traffic Generation**
- **Hidden WKWebViews** — Real WebKit browser engine with JavaScript execution, cookie persistence, and Safari user agents. Sites see normal browser traffic.
- **Isolated cookie stores** — Each module gets its own persistent cookie store (via `WKWebsiteDataStore`). The search persona and shopping persona don't leak into each other.
- **Anti-detection JS** — Spoofs `navigator.webdriver`, normalizes plugin arrays, and fakes the Page Visibility API (so YouTube doesn't pause).

**Scheduling**
- **Poisson-distributed timing** — Activity intervals follow an exponential distribution (not fixed timers), which looks more natural.
- **Time-of-day awareness** — More active during afternoon/evening, less at 3 AM. Includes "Vampire mode" for occasional late-night activity.
- **Weekend/weekday variation** — Weekends have different activity patterns (later mornings, more browsing).

**Security & Anti-Detection**
- **Safari user agent rotation** — Each session gets a random Safari UA (17.x–18.x) matching WKWebView's TLS fingerprint for consistency.
- **HTTPS-only** — App Transport Security enforced. No plaintext HTTP traffic that would leak full URL paths.
- **Blocked domain enforcement** — Checked across all four modules and as a safety net at the WebView level. URL schemes are validated to reject `file://`, `javascript:`, and `data:` loads.
- **Thread-safe logging** — Activity log writes are serialized via a dispatch queue to prevent data races when multiple modules run concurrently.
- **JS injection hardening** — User-provided data (persona interests, blocked domains) is escaped for backticks, template literals, null bytes, and script breakout before injection into WebView JavaScript.

## What It Doesn't Do

This is **network-level obfuscation**, not website-level bot evasion:

- Won't fool Google reCAPTCHA or Amazon's bot detection
- Won't bypass CAPTCHAs
- Won't create accounts or log into services
- Won't interact with your personal browsing or cookies

The goal is to make your household's aggregate traffic look like 2+ people, not to impersonate a human to individual websites.

## Known Limitations

### TLS Fingerprinting

The app uses WKWebView (Apple's WebKit engine) for all browsing. WKWebView's TLS ClientHello has a known fingerprint (JA3/JA4) that matches Safari/WebKit. ISPs or network middleboxes that perform TLS fingerprinting can distinguish this traffic from other browsers.

The app uses Safari-only user agents to minimize this mismatch — Safari's TLS fingerprint is the closest match to WKWebView's. This means the traffic is **effective against passive aggregate profiling** (hostname/URL pattern analysis) but **not against active TLS fingerprint analysis**.

### DNS Visibility

All hostname lookups are standard plaintext DNS queries visible to your ISP. Even with HTTPS, the ISP sees every hostname the app resolves. If DNS privacy matters to you, configure system-level DNS-over-HTTPS using a service like [NextDNS](https://nextdns.io), [Cloudflare WARP](https://1.1.1.1), or a macOS DoH configuration profile.

### App Sandbox

The app runs without macOS App Sandbox restrictions (`com.apple.security.app-sandbox = false`). This is required for WKWebView to function correctly with isolated cookie stores and custom configurations. WKWebView's own multi-process architecture provides isolation — web content runs in a separate process from the app. However, this means WebKit vulnerabilities have a larger attack surface than in a sandboxed app.

## Requirements

- macOS 14.0 (Sonoma) or later
- No external dependencies

## Installation

### From DMG (Recommended)
1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Digital Roommate** to Applications
3. Launch from Applications — it appears in the menu bar, not the Dock

### From Source
```bash
git clone https://github.com/madebysan/digital-roommate.git
cd digital-roommate
swift build -c release
# Binary is at .build/release/DigitalRoommate
```

## Usage

### First Launch — Onboarding

On first run, a 5-step onboarding wizard walks you through:
1. **Welcome** — what the app does and how it works
2. **Modules** — toggle which traffic types to generate (search, shopping, video, news)
3. **Activity level** — Low / Medium / High with sessions-per-hour estimates
4. **Persona** — meet your fake roommate
5. **Summary** — review your choices and start

The scheduler doesn't start until you click "Get Started." All onboarding controls are VoiceOver-accessible.

### Menu Bar

Click the person icon in the menu bar to see:
- Module status (enabled/disabled, current activity)
- Toggle individual modules on/off
- Pause/Resume all activity
- Enable Launch at Login
- Open the activity log

### Settings

The settings window uses a sidebar layout with 7 sections:

| Section | What You Configure |
|---------|-------------------|
| **General** | Activity level, active time blocks, max concurrent browsers, launch at login |
| **Search** | Search engine toggles (Google, Bing, DuckDuckGo), burst mode, click-through |
| **Shopping** | Products per session, image browsing, review scrolling |
| **Video** | Max watch duration, ad skipping, mute |
| **News** | Articles per session, sites per session, follow related links |
| **Sites & Privacy** | Visited sites list, blocked domains |
| **Persona** | Active persona picker, randomize, export, reset, edit interests/topics/categories |

Toggle controls use NSSwitch for on/off settings and NSPopUpButton for numeric options. Changes apply immediately (except Persona, which has a Save button). The layout follows macOS System Settings conventions — sidebar navigation, card-grouped controls, and uppercase section headers.

### Activity Log

The app writes a JSON activity log to:
```
~/Library/Application Support/DigitalRoommate/activity-log.json
```

Each entry records what module did what and when — useful for verifying the app is generating the traffic you expect.

### Customizing the Persona

Personas are stored in:
```
~/Library/Application Support/DigitalRoommate/personas/
```

You can manage personas from Settings > Persona:
- **Switch** between multiple saved personas
- **Randomize** to generate a new persona with random interests
- **Export** the current persona as a JSON file
- **Edit** interests, search topics, shopping categories, and video preferences inline
- **Open** the JSON file directly for advanced editing

Each persona defines:
- **Search topics** — Categories, query templates, and items to search for
- **Shopping categories** — Amazon search terms and product URLs
- **Video interests** — YouTube channels, search queries, and specific video URLs
- **News sites** — Homepages to visit with article reading simulation
- **Active hours** — Weight (0.0–1.0) for each time block controlling activity level

## Architecture

```
Sources/DigitalRoommate/
├── main.swift                    # App entry point
├── AppDelegate.swift             # Lifecycle, App Nap prevention
├── Core/
│   ├── BrowsingEngine.swift      # Offscreen WKWebView pool (max 3)
│   ├── WebViewInstance.swift      # WKWebView wrapper with URL/scheme validation + async helpers
│   ├── Scheduler.swift           # Poisson-distributed, time-aware scheduling
│   ├── ModuleRegistry.swift      # Module lifecycle management
│   └── BrowsingModule.swift      # Protocol for all modules
├── Modules/
│   ├── SearchNoiseModule.swift   # Google/Bing/DDG search + click-through + JS escaping
│   ├── ShoppingNoiseModule.swift # Amazon browsing with blocked domain checks
│   ├── VideoNoiseModule.swift    # YouTube watching with ad skip + watch history (FIFO)
│   └── NewsModule.swift          # News reading with blocked domain-aware link following
├── Persona/
│   ├── Persona.swift             # Codable persona model + multi-persona storage
│   ├── PersonaGenerator.swift    # Random persona generation
│   ├── PersonaSchedule.swift     # Time-based activity decisions
│   └── QueryGenerator.swift      # Template-based search query generation
├── Settings/
│   ├── AppSettings.swift         # All user-configurable settings (Codable)
│   └── SettingsManager.swift     # Singleton settings persistence (UserDefaults)
├── UI/
│   ├── Styles.swift              # Design system tokens, card builders, button helpers
│   ├── StatusBarController.swift # Menu bar icon and dropdown
│   ├── SettingsWindowController.swift  # Sidebar settings with accessible controls
│   ├── OnboardingWindowController.swift # 5-step wizard with step transitions
│   └── HelpWindowController.swift      # Native AppKit help/about window
├── Persistence/
│   └── StateStore.swift          # JSON state files + thread-safe activity log (debug-only stdout)
├── Testing/
│   ├── TestRunner.swift          # Test execution framework
│   ├── TestConfig.swift          # Test configuration
│   ├── TestPersonas.swift        # Test persona fixtures
│   └── MockWebViewInstance.swift # WKWebView mock for testing
└── AntiDetection/
    ├── UserAgentProvider.swift    # Safari-only UA rotation (17.x–18.x)
    └── StealthScripts.swift      # Navigator + visibility spoofing (no WebGL override)
```

## Privacy & Security

**Your data stays yours:**
- All browsing happens in isolated WKWebViews — your personal browser cookies and history are never touched
- No data is sent to any server — the app only generates outbound web traffic to public websites
- The activity log stays local on your machine
- No analytics, telemetry, or phone-home behavior
- Zero third-party dependencies — built entirely on Apple frameworks

**Hardened by design:**
- HTTPS-only — App Transport Security enforced, no plaintext HTTP traffic
- Activity log output suppressed in release builds to prevent URL leaking via stdout
- All URLs from persona files validated at load time — rejects `file://`, `javascript:`, `data:` schemes
- Blocked domains enforced across all four modules and at the WebView level as a safety net
- Thread-safe logging via serial dispatch queue prevents data races under concurrent module execution
- JavaScript injection uses hardened escaping (backticks, template literals, null bytes, script breakout)
- Safari-only user agents match WKWebView's TLS fingerprint — no Chrome/Firefox/Edge mismatch

## License

MIT
