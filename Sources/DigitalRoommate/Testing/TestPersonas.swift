import Foundation

// Pre-built test persona with intentionally unique, grep-friendly interests.
// If "underwater basket weaving" appears in the activity log, we know the
// persona interests are being followed correctly.
struct TestPersonas {

    /// The primary test persona — interests are absurd enough to be unmistakable
    static let zephyrMoonwhale = Persona(
        name: "Zephyr Moonwhale",
        age: 29,
        profession: "Interdimensional Basket Weaver",
        interests: ["underwater basket weaving", "sparkle horn polishing", "competitive ferret racing"],
        searchTopics: [
            Persona.SearchTopic(
                category: "underwater basket weaving",
                templates: [
                    "best {item} for beginners",
                    "how to {item} underwater",
                    "{item} tutorial 2025",
                    "advanced {item} techniques"
                ],
                items: [
                    "underwater basket weaving",
                    "subaquatic reed braiding",
                    "deep sea macrame",
                    "aquatic fiber arts"
                ]
            ),
            Persona.SearchTopic(
                category: "sparkle horn polish",
                templates: [
                    "{item} reviews",
                    "where to buy {item}",
                    "best {item} brands",
                    "{item} comparison"
                ],
                items: [
                    "sparkle horn polish",
                    "unicorn horn buffing compound",
                    "iridescent horn wax",
                    "enchanted horn sealant"
                ]
            ),
            Persona.SearchTopic(
                category: "tesseract clay",
                templates: [
                    "{item} tutorial",
                    "how to make {item}",
                    "{item} for beginners",
                    "advanced {item} workshop"
                ],
                items: [
                    "tesseract clay throwing",
                    "four-dimensional pottery",
                    "hypercube ceramics",
                    "quantum clay sculpting"
                ]
            ),
        ],
        shoppingCategories: [
            Persona.ShoppingCategory(
                name: "Holographic Crafts",
                searchTerms: [
                    "holographic yarn",
                    "artisanal moon dust",
                    "bioluminescent terrarium kit",
                    "prismatic weaving needles"
                ],
                productUrls: []
            ),
            Persona.ShoppingCategory(
                name: "Ferret Racing Gear",
                searchTerms: [
                    "competitive ferret racing harness",
                    "ferret agility tunnel set",
                    "premium ferret racing track",
                    "ferret victory celebration banner"
                ],
                productUrls: []
            ),
        ],
        videoInterests: [
            Persona.VideoInterest(
                topic: "competitive ferret racing",
                channelUrls: [],
                videoUrls: [],
                searchQueries: [
                    "competitive ferret racing championship",
                    "ferret agility training tips",
                    "world ferret racing finals 2025",
                    "how to train a racing ferret"
                ]
            ),
            Persona.VideoInterest(
                topic: "ASMR blacksmithing",
                channelUrls: [],
                videoUrls: [],
                searchQueries: [
                    "ASMR blacksmithing no talking",
                    "relaxing forge sounds ASMR",
                    "medieval sword making ASMR",
                    "soothing anvil strikes compilation"
                ]
            ),
            Persona.VideoInterest(
                topic: "spaghetti knitting",
                channelUrls: [],
                videoUrls: [],
                searchQueries: [
                    "how to knit with spaghetti",
                    "pasta fiber arts tutorial",
                    "spaghetti scarf knitting pattern",
                    "noodle crafts for beginners"
                ]
            ),
        ],
        newsSites: [
            Persona.NewsSite(name: "Ars Technica", url: "https://arstechnica.com", category: "tech"),
            Persona.NewsSite(name: "NPR", url: "https://www.npr.org", category: "news"),
            Persona.NewsSite(name: "The Verge", url: "https://www.theverge.com", category: "tech"),
            Persona.NewsSite(name: "Reuters", url: "https://www.reuters.com", category: "news"),
        ],
        activeHours: Persona.ActiveHours(
            morningWeight: 1.0,
            afternoonWeight: 1.0,
            eveningWeight: 1.0,
            lateNightWeight: 1.0,
            vampireWeight: 1.0
        )
    )

    /// Save the test persona to the personas directory
    static func install() {
        Persona.save(zephyrMoonwhale, named: zephyrMoonwhale.name)
    }
}
