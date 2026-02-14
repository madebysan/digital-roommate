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

- **Hidden WKWebViews** — Real WebKit browser engine with JavaScript execution, cookie persistence, and custom user agents. Sites see normal browser traffic.
- **Isolated cookie stores** — Each module gets its own persistent cookie store (via `WKWebsiteDataStore`). The search persona and shopping persona don't leak into each other.
- **Anti-detection JS** — Spoofs `navigator.webdriver`, normalizes plugin arrays, fakes Page Visibility API (so YouTube doesn't pause), and normalizes WebGL fingerprints.
- **Poisson-distributed timing** — Activity intervals follow an exponential distribution (not fixed timers), which looks more natural.
- **Time-of-day awareness** — More active during afternoon/evening, less at 3 AM. Includes "Vampire mode" for occasional late-night activity.
- **Weekend/weekday variation** — Weekends have different activity patterns (later mornings, more browsing).
- **User agent rotation** — Each browsing session gets a random desktop browser UA from a bundled list.

## What It Doesn't Do

This is **network-level obfuscation**, not website-level bot evasion:

- Won't fool Google reCAPTCHA or Amazon's bot detection
- Won't bypass CAPTCHAs
- Won't create accounts or log into services
- Won't interact with your personal browsing or cookies

The goal is to make your household's aggregate traffic look like 2+ people, not to impersonate a human to individual websites.

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

### Menu Bar

Click the person icon in the menu bar to see:
- Module status (enabled/disabled, current activity)
- Toggle individual modules on/off
- Pause/Resume all activity
- Enable Launch at Login
- Open the activity log

### Activity Log

The app writes a JSON activity log to:
```
~/Library/Application Support/DigitalRoommate/activity-log.json
```

Each entry records what module did what and when — useful for verifying the app is generating the traffic you expect.

### Customizing the Persona

Edit the default persona at:
```
~/Library/Application Support/DigitalRoommate/persona.json
```

If this file doesn't exist, copy and modify the bundled `Resources/persona-default.json`. The persona defines:

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
│   ├── WebViewInstance.swift      # Single WKWebView wrapper with async helpers
│   ├── Scheduler.swift           # Poisson-distributed, time-aware scheduling
│   ├── ModuleRegistry.swift      # Module lifecycle management
│   └── BrowsingModule.swift      # Protocol for all modules
├── Modules/
│   ├── SearchNoiseModule.swift   # Google/Bing/DDG search + click-through
│   ├── ShoppingNoiseModule.swift # Amazon browsing simulation
│   ├── VideoNoiseModule.swift    # YouTube watching with ad skip
│   └── NewsModule.swift          # News reading with link following
├── Persona/
│   ├── Persona.swift             # Codable persona model
│   ├── PersonaSchedule.swift     # Time-based activity decisions
│   └── QueryGenerator.swift      # Template-based search query generation
├── UI/
│   └── StatusBarController.swift # Menu bar icon and dropdown
├── Persistence/
│   └── StateStore.swift          # JSON state files + activity log
└── AntiDetection/
    ├── UserAgentProvider.swift    # UA rotation from bundled list
    └── StealthScripts.swift      # JS injected at document start
```

## Privacy

- All browsing happens in isolated WKWebViews — your personal browser cookies and history are never touched
- No data is sent to any server (the app only generates outbound web traffic to public websites)
- The activity log stays local on your machine
- No analytics, telemetry, or phone-home behavior

## License

MIT
