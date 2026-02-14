import Foundation

// Generates realistic search queries from templates and topic data.
// Uses the persona's search topics to create varied queries that
// look like a real person exploring interests.
struct QueryGenerator {

    let persona: Persona

    /// Generate a single search query from the persona's interests.
    /// May produce a standalone query or a burst of related queries.
    func generateQuery() -> String {
        guard !persona.searchTopics.isEmpty else {
            return "best coffee maker 2024"
        }

        let topic = persona.searchTopics.randomElement()!
        let template = topic.templates.randomElement()!
        let item = topic.items.randomElement()!

        // Replace {item} placeholder with a random item
        var query = template.replacingOccurrences(of: "{item}", with: item)

        // Occasionally add the current year to make it look current
        if Bool.random() && !query.contains("202") {
            query += " \(Calendar.current.component(.year, from: Date()))"
        }

        return query
    }

    /// Generate a burst of 3-5 related queries (simulates a research session).
    /// People don't just search once — they refine and explore.
    func generateBurst() -> [String] {
        guard !persona.searchTopics.isEmpty else {
            return ["best coffee maker 2024"]
        }

        // Pick one topic for the burst — all queries will be related
        let topic = persona.searchTopics.randomElement()!
        let item = topic.items.randomElement()!
        let count = Int.random(in: 3...5)

        var queries: [String] = []

        // First query: broad search
        queries.append(topic.templates.randomElement()!.replacingOccurrences(of: "{item}", with: item))

        // Subsequent queries: refinements and related searches
        let refinements = [
            "\(item) reviews",
            "\(item) vs",
            "best \(item) under $100",
            "\(item) for beginners",
            "\(item) reddit recommendations",
            "is \(item) worth it",
            "\(item) comparison \(Calendar.current.component(.year, from: Date()))",
            "where to buy \(item)",
            "\(item) tips and tricks",
            "\(item) alternatives"
        ]

        let shuffled = refinements.shuffled()
        for i in 0..<min(count - 1, shuffled.count) {
            queries.append(shuffled[i])
        }

        return queries
    }
}
