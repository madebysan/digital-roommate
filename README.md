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

### First Launch — Onboarding

On first run, a 5-step onboarding wizard walks you through:
1. Welcome overview
2. Module selection (toggle which traffic types to generate)
3. Activity level (Low / Medium / High)
4. Persona introduction
5. Summary and confirmation

The scheduler doesn't start until you click "Get Started."

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

Toggle controls use NSSwitch for on/off settings and NSPopUpButton for numeric options. Changes apply immediately (except Persona, which has a Save button).

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
│   ├── Persona.swift             # Codable persona model + multi-persona storage
│   ├── PersonaGenerator.swift    # Random persona generation
│   ├── PersonaSchedule.swift     # Time-based activity decisions
│   └── QueryGenerator.swift      # Template-based search query generation
├── Settings/
│   ├── AppSettings.swift         # All user-configurable settings (Codable)
│   └── SettingsManager.swift     # Singleton settings persistence (UserDefaults)
├── UI/
│   ├── Styles.swift              # Shared visual constants and UI helpers
│   ├── StatusBarController.swift # Menu bar icon and dropdown
│   ├── SettingsWindowController.swift  # Sidebar-based settings window
│   ├── OnboardingWindowController.swift # 5-step first-run wizard
│   └── HelpWindowController.swift      # Help/about window
├── Persistence/
│   └── StateStore.swift          # JSON state files + activity log
├── Testing/
│   ├── TestRunner.swift          # Test execution framework
│   ├── TestConfig.swift          # Test configuration
│   ├── TestPersonas.swift        # Test persona fixtures
│   └── MockWebViewInstance.swift # WKWebView mock for testing
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
