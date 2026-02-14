import Foundation

// The fake "roommate" persona — defines what kind of person the traffic
// should look like. Includes interests, profession, search patterns,
// shopping preferences, video tastes, and news sources.
struct Persona: Codable {
    let name: String
    let age: Int
    let profession: String
    let interests: [String]

    // Module-specific data
    let searchTopics: [SearchTopic]
    let shoppingCategories: [ShoppingCategory]
    let videoInterests: [VideoInterest]
    let newsSites: [NewsSite]

    // Schedule preferences (which time blocks this persona is most active)
    let activeHours: ActiveHours

    struct SearchTopic: Codable {
        let category: String         // e.g., "cooking", "woodworking"
        let templates: [String]      // e.g., "best {item} for beginners"
        let items: [String]          // e.g., ["chef knife", "cutting board"]
    }

    struct ShoppingCategory: Codable {
        let name: String             // e.g., "Kitchen Appliances"
        let searchTerms: [String]    // Amazon search queries
        let productUrls: [String]    // Direct product page URLs
    }

    struct VideoInterest: Codable {
        let topic: String            // e.g., "woodworking tutorials"
        let channelUrls: [String]    // YouTube channel URLs
        let videoUrls: [String]      // Specific video URLs
        let searchQueries: [String]  // YouTube search queries
    }

    struct NewsSite: Codable {
        let name: String             // e.g., "Ars Technica"
        let url: String              // Homepage URL
        let category: String         // "tech", "news", "hobby", "professional"
    }

    struct ActiveHours: Codable {
        let morningWeight: Double    // 0.0-1.0, how likely to be active
        let afternoonWeight: Double
        let eveningWeight: Double
        let lateNightWeight: Double
        let vampireWeight: Double
    }
}

// MARK: - Loading

extension Persona {
    /// Load the default persona from the bundled JSON resource
    static func loadDefault() -> Persona {
        // Try to load from Application Support first (user-edited version)
        let appSupport = StateStore.appSupportDirectory
        let customPath = appSupport.appendingPathComponent("persona.json")

        if FileManager.default.fileExists(atPath: customPath.path),
           let data = try? Data(contentsOf: customPath),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            return persona
        }

        // Fall back to bundled default
        if let url = Bundle.main.url(forResource: "persona-default", withExtension: "json", subdirectory: "Resources"),
           let data = try? Data(contentsOf: url),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            return persona
        }

        // Last resort: hardcoded minimal persona
        return Persona.fallback
    }

    /// Minimal fallback persona if JSON loading fails
    static let fallback = Persona(
        name: "Alex",
        age: 34,
        profession: "Marketing Manager",
        interests: ["cooking", "hiking", "photography"],
        searchTopics: [
            SearchTopic(
                category: "cooking",
                templates: ["best {item} for beginners", "how to {item} at home", "{item} recipes easy"],
                items: ["sourdough bread", "cast iron skillet", "meal prep", "air fryer"]
            )
        ],
        shoppingCategories: [
            ShoppingCategory(
                name: "Kitchen",
                searchTerms: ["cast iron skillet", "chef knife set", "cutting board wood"],
                productUrls: []
            )
        ],
        videoInterests: [
            VideoInterest(
                topic: "cooking",
                channelUrls: [],
                videoUrls: [],
                searchQueries: ["easy weeknight dinners", "sourdough bread tutorial", "meal prep ideas"]
            )
        ],
        newsSites: [
            NewsSite(name: "Ars Technica", url: "https://arstechnica.com", category: "tech"),
            NewsSite(name: "NPR", url: "https://www.npr.org", category: "news")
        ],
        activeHours: ActiveHours(
            morningWeight: 0.6,
            afternoonWeight: 0.8,
            eveningWeight: 0.9,
            lateNightWeight: 0.3,
            vampireWeight: 0.1
        )
    )
}
