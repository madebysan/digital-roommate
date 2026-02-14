import Foundation

// The fake "roommate" persona — defines what kind of person the traffic
// should look like. Includes interests, profession, search patterns,
// shopping preferences, video tastes, and news sources.
// Multiple personas can be stored in the personas/ directory.
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

// MARK: - Multi-Persona Storage

extension Persona {

    /// Directory where all persona files are stored
    static var personasDirectory: URL {
        let dir = StateStore.appSupportDirectory.appendingPathComponent("personas")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// List all available persona names (derived from filenames, sorted)
    static func listAll() -> [String] {
        let dir = personasDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Load a specific persona by name
    static func load(named name: String) -> Persona? {
        let file = personasDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Persona.self, from: data)
    }

    /// Save a persona to a named file in the personas directory
    static func save(_ persona: Persona, named name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(persona) else { return }
        let file = personasDirectory.appendingPathComponent("\(name).json")
        try? data.write(to: file, options: .atomic)
    }

    /// Delete a persona file by name
    static func delete(named name: String) {
        let file = personasDirectory.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: file)
    }

    /// Path to the active persona's file
    static var activePersonaFilePath: URL {
        let name = SettingsManager.shared.current.activePersonaName
        return personasDirectory.appendingPathComponent("\(name).json")
    }
}

// MARK: - Loading & Migration

extension Persona {

    /// Load the active persona (set in Settings).
    /// Falls through multiple sources: active file → any persona → old persona.json → bundled → hardcoded.
    static func loadDefault() -> Persona {
        let activeName = SettingsManager.shared.current.activePersonaName

        // 1. Try the active persona
        if let persona = load(named: activeName) {
            return persona
        }

        // 2. Fall back to any persona in the directory
        if let firstName = listAll().first, let persona = load(named: firstName) {
            return persona
        }

        // 3. Fall back to old persona.json (pre-migration)
        let oldPath = StateStore.appSupportDirectory.appendingPathComponent("persona.json")
        if FileManager.default.fileExists(atPath: oldPath.path),
           let data = try? Data(contentsOf: oldPath),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            return persona
        }

        // 4. Fall back to bundled default
        if let url = Bundle.main.url(forResource: "persona-default", withExtension: "json", subdirectory: "Resources"),
           let data = try? Data(contentsOf: url),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            return persona
        }

        // 5. Last resort
        return Persona.fallback
    }

    /// Migrate old persona.json into the personas/ directory.
    /// Called once on launch — safe to call multiple times.
    static func migrateIfNeeded() {
        let oldPath = StateStore.appSupportDirectory.appendingPathComponent("persona.json")
        guard FileManager.default.fileExists(atPath: oldPath.path) else { return }

        if let data = try? Data(contentsOf: oldPath),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            save(persona, named: persona.name)
        }

        try? FileManager.default.removeItem(at: oldPath)
    }

    /// Ensure at least one persona exists in the personas/ directory.
    static func ensureDefaultExists() {
        let existing = listAll()
        guard existing.isEmpty else { return }

        // Copy bundled default
        if let url = Bundle.main.url(forResource: "persona-default", withExtension: "json", subdirectory: "Resources"),
           let data = try? Data(contentsOf: url),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            save(persona, named: persona.name)
        } else {
            save(fallback, named: fallback.name)
        }
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
