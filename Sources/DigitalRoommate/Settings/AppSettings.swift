import Foundation

// All user-configurable settings in a single Codable struct.
// Every field has a sensible default so the app works out of the box.
struct AppSettings: Codable, Equatable {

    // MARK: - General

    var activityLevel: ActivityLevel = .medium

    // Time blocks when the app is allowed to run
    var morningEnabled: Bool = true
    var afternoonEnabled: Bool = true
    var eveningEnabled: Bool = true
    var lateNightEnabled: Bool = true
    var vampireEnabled: Bool = true
    var earlyMorningEnabled: Bool = true

    var maxConcurrentBrowsers: Int = 3
    var launchAtLogin: Bool = false

    // MARK: - Module Enables

    var searchEnabled: Bool = true
    var shoppingEnabled: Bool = true
    var videoEnabled: Bool = true
    var newsEnabled: Bool = true

    // MARK: - Search Settings

    var searchGoogle: Bool = true
    var searchBing: Bool = true
    var searchDuckDuckGo: Bool = true
    var searchBurstMode: Bool = true
    var searchClickThrough: Bool = true

    // MARK: - Shopping Settings

    var shoppingProductsPerSession: Int = 2
    var shoppingBrowseImages: Bool = true
    var shoppingScrollToReviews: Bool = true

    // MARK: - Video Settings

    var videoMaxWatchMinutes: Int = 10
    var videoAutoSkipAds: Bool = true
    var videoMute: Bool = true

    // MARK: - News Settings

    var newsArticlesPerSession: Int = 3
    var newsFollowRelatedLinks: Bool = true
    var newsSitesPerSession: Int = 2

    // MARK: - Active Persona

    var activePersonaName: String = "Alex Rivera"

    // MARK: - Visited Sites

    // All sites the roommate visits. When empty, auto-populated from persona defaults.
    // Users can add or remove sites from Settings → Sites & Privacy.
    var visitedSites: [String] = []

    // MARK: - Blocked Domains

    // Domains the roommate will never visit (e.g., ["facebook.com", "reddit.com"]).
    // Checked against the hostname of any URL before loading.
    var blockedDomains: [String] = []

    // MARK: - Activity Level

    enum ActivityLevel: String, Codable, CaseIterable {
        case low
        case medium
        case high

        // Multiplier applied to the Poisson delay in Scheduler.
        // Higher multiplier = longer intervals = less traffic.
        var intervalMultiplier: Double {
            switch self {
            case .low:    return 2.0
            case .medium: return 1.0
            case .high:   return 0.5
            }
        }

        var displayName: String {
            switch self {
            case .low:    return "Low"
            case .medium: return "Medium"
            case .high:   return "High"
            }
        }

        var description: String {
            switch self {
            case .low:
                return "A few searches and page visits per hour. Minimal bandwidth \u{2014} you won\u{2019}t notice it."
            case .medium:
                return "Regular browsing, video watching, and shopping throughout the day. Uses about as much data as casual phone browsing."
            case .high:
                return "Frequent sessions across all modules. Uses noticeably more bandwidth \u{2014} like having a second person actively using your internet."
            }
        }

        var sessionsPerHour: String {
            switch self {
            case .low:    return "~2\u{2013}3 sessions/hour"
            case .medium: return "~5\u{2013}8 sessions/hour"
            case .high:   return "~10\u{2013}15 sessions/hour"
            }
        }
    }

    // MARK: - Helpers

    // Returns the list of enabled search engines as SearchNoiseModule.SearchEngine cases
    var enabledSearchEngines: [String] {
        var engines: [String] = []
        if searchGoogle { engines.append("Google") }
        if searchBing { engines.append("Bing") }
        if searchDuckDuckGo { engines.append("DuckDuckGo") }
        return engines
    }

    // Check if a URL's domain is blocked
    func isDomainBlocked(_ urlString: String) -> Bool {
        guard !blockedDomains.isEmpty,
              let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return blockedDomains.contains { blocked in
            let domain = blocked.lowercased().trimmingCharacters(in: .whitespaces)
            return host == domain || host.hasSuffix(".\(domain)")
        }
    }

    // Returns the visited sites list, generating defaults from persona if empty.
    var effectiveVisitedSites: [String] {
        return visitedSites.isEmpty ? AppSettings.defaultVisitedSites() : visitedSites
    }

    // Sites for the News module — filters out search engines, Amazon, and YouTube
    // since those have dedicated modules with specialized behavior.
    var browsingSites: [String] {
        let moduleSpecific: Set<String> = [
            "www.google.com", "google.com",
            "www.bing.com", "bing.com",
            "duckduckgo.com", "www.duckduckgo.com",
            "www.amazon.com", "amazon.com",
            "www.youtube.com", "youtube.com",
        ]
        return effectiveVisitedSites.filter { urlString in
            guard let host = URL(string: urlString)?.host?.lowercased() else { return true }
            return !moduleSpecific.contains(host)
        }
    }

    // Generate the default visited sites list from persona + known module sites.
    static func defaultVisitedSites() -> [String] {
        let persona = Persona.loadDefault()
        var sites: [String] = []
        sites.append("https://www.google.com")
        sites.append("https://www.bing.com")
        sites.append("https://duckduckgo.com")
        sites.append("https://www.amazon.com")
        sites.append("https://www.youtube.com")
        for site in persona.newsSites {
            sites.append(site.url)
        }
        return sites
    }

    // Check if a given time block is enabled
    func isTimeBlockEnabled(_ block: String) -> Bool {
        switch block {
        case "morning":    return morningEnabled
        case "afternoon":  return afternoonEnabled
        case "evening":    return eveningEnabled
        case "lateNight":  return lateNightEnabled
        case "vampire":    return vampireEnabled
        case "earlyMorn":  return earlyMorningEnabled
        default:           return true
        }
    }
}
