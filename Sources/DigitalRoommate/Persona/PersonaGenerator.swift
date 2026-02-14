import Foundation

// Generates random, realistic personas for traffic generation.
// Each persona gets a random combination of 3-5 interest areas,
// plus shuffled news sites and activity hour weights.
enum PersonaGenerator {

    // MARK: - Public

    static func randomPersona() -> Persona {
        let name = names.randomElement()!
        let prof = professions.randomElement()!
        let interestCount = Int.random(in: 3...5)
        let bundles = Array(interestBundles.shuffled().prefix(interestCount))
        let newsCount = Int.random(in: 4...7)
        let news = Array(allNewsSites.shuffled().prefix(newsCount))

        return Persona(
            name: name,
            age: Int.random(in: 22...55),
            profession: prof,
            interests: bundles.map { $0.interest },
            searchTopics: bundles.map { b in
                Persona.SearchTopic(
                    category: b.interest,
                    templates: b.searchTemplates,
                    items: Array(b.searchItems.shuffled().prefix(Int.random(in: 4...8)))
                )
            },
            shoppingCategories: bundles.compactMap { b in
                guard !b.shoppingTerms.isEmpty else { return nil }
                return Persona.ShoppingCategory(
                    name: b.shoppingCategory,
                    searchTerms: Array(b.shoppingTerms.shuffled().prefix(Int.random(in: 3...5))),
                    productUrls: []
                )
            },
            videoInterests: bundles.map { b in
                Persona.VideoInterest(
                    topic: b.interest,
                    channelUrls: [],
                    videoUrls: [],
                    searchQueries: Array(b.videoQueries.shuffled().prefix(Int.random(in: 3...5)))
                )
            },
            newsSites: news.map { Persona.NewsSite(name: $0.0, url: $0.1, category: $0.2) },
            activeHours: Persona.ActiveHours(
                morningWeight: Double.random(in: 0.3...0.8),
                afternoonWeight: Double.random(in: 0.5...0.9),
                eveningWeight: Double.random(in: 0.6...1.0),
                lateNightWeight: Double.random(in: 0.1...0.5),
                vampireWeight: Double.random(in: 0.0...0.2)
            )
        )
    }

    // MARK: - Data Pools

    private static let names = [
        "Morgan Chen", "Jordan Brooks", "Riley Patel", "Casey Navarro",
        "Sam Tanaka", "Taylor Quinn", "Drew Martinez", "Jamie Okafor",
        "Avery Singh", "Dakota Wells", "Reese Kim", "Finley Cooper",
        "Hayden Park", "Cameron West", "Rowan Murphy", "Sage Thompson",
        "Quinn Delgado", "Jesse Nakamura", "Emery Foster", "Parker Reeves",
    ]

    private static let professions = [
        "Marketing Manager", "Software Developer", "Nurse", "Teacher",
        "Graphic Designer", "Accountant", "Project Manager", "Sales Rep",
        "Data Analyst", "Physical Therapist", "Architect", "Product Manager",
        "Consultant", "Freelance Writer", "Operations Manager", "HR Specialist",
    ]

    private struct Bundle {
        let interest: String
        let shoppingCategory: String
        let searchTemplates: [String]
        let searchItems: [String]
        let shoppingTerms: [String]
        let videoQueries: [String]
    }

    private static let interestBundles: [Bundle] = [
        Bundle(
            interest: "cooking",
            shoppingCategory: "Kitchen & Cooking",
            searchTemplates: ["best {item} for beginners", "how to {item} at home", "{item} recipes easy", "{item} tips"],
            searchItems: ["sourdough bread", "cast iron skillet", "meal prep ideas", "air fryer recipes", "homemade pasta", "wok cooking", "fermented vegetables", "knife sharpening", "dutch oven", "smoker recipes", "batch cooking", "instant pot recipes"],
            shoppingTerms: ["cast iron skillet", "chef knife set", "dutch oven", "cutting board wood", "instant pot", "air fryer", "kitchen scale"],
            videoQueries: ["easy weeknight dinners", "sourdough bread tutorial", "meal prep ideas", "wok cooking techniques", "homemade pasta recipe"]
        ),
        Bundle(
            interest: "hiking",
            shoppingCategory: "Outdoor & Hiking",
            searchTemplates: ["best {item} for hiking", "{item} review", "top rated {item}", "{item} buying guide"],
            searchItems: ["hiking boots", "trekking poles", "daypack", "hiking trails near me", "trail running shoes", "water filter backpacking", "hiking GPS", "bear canister", "hammock camping", "ultralight gear"],
            shoppingTerms: ["hiking boots waterproof", "trekking poles lightweight", "daypack 30L", "water filter hiking", "merino wool socks"],
            videoQueries: ["best day hikes", "hiking gear review", "backpacking tips beginners", "trail running tips", "national park hiking"]
        ),
        Bundle(
            interest: "photography",
            shoppingCategory: "Photography",
            searchTemplates: ["best {item} for beginners", "{item} tutorial", "how to {item}", "{item} comparison"],
            searchItems: ["landscape photography tips", "portrait lighting setup", "photo editing workflow", "mirrorless camera", "wide angle lens", "macro photography", "street photography", "golden hour", "astrophotography"],
            shoppingTerms: ["camera tripod", "memory card 128gb", "lens cleaning kit", "camera bag", "ND filter set", "portable reflector"],
            videoQueries: ["photography tips beginners", "lightroom editing tutorial", "portrait photography techniques", "landscape composition", "street photography"]
        ),
        Bundle(
            interest: "home improvement",
            shoppingCategory: "Home & Tools",
            searchTemplates: ["how to {item}", "DIY {item}", "best {item} for home", "{item} step by step"],
            searchItems: ["bathroom renovation", "paint interior walls", "install floating shelves", "fix leaky faucet", "tile backsplash", "build deck", "refinish hardwood floors", "drywall repair", "crown molding"],
            shoppingTerms: ["cordless drill", "level laser", "stud finder", "paint sprayer", "wood filler", "tile saw", "sandpaper assortment"],
            videoQueries: ["DIY bathroom renovation", "how to paint a room", "install floating shelves", "beginner woodworking projects", "home repair basics"]
        ),
        Bundle(
            interest: "personal finance",
            shoppingCategory: "Books & Education",
            searchTemplates: ["best {item}", "how to {item}", "{item} for beginners", "{item} strategy"],
            searchItems: ["high yield savings", "index fund investing", "retirement planning", "credit score improve", "budget template", "roth ira vs traditional", "real estate investing", "emergency fund", "tax optimization"],
            shoppingTerms: ["personal finance book", "budget planner", "financial calculator", "investing beginners book"],
            videoQueries: ["index fund investing explained", "how to budget effectively", "retirement planning by age", "passive income ideas", "stock market basics"]
        ),
        Bundle(
            interest: "fitness",
            shoppingCategory: "Fitness & Health",
            searchTemplates: ["best {item}", "{item} for beginners", "how to {item}", "{item} workout plan"],
            searchItems: ["strength training routine", "HIIT workout", "yoga for flexibility", "running plan 5k", "protein intake", "home gym setup", "foam rolling", "progressive overload", "mobility exercises"],
            shoppingTerms: ["resistance bands", "yoga mat", "foam roller", "adjustable dumbbells", "pull up bar", "running shoes", "protein powder"],
            videoQueries: ["full body workout home", "yoga for beginners", "running form tips", "strength training beginners", "stretching routine"]
        ),
        Bundle(
            interest: "gaming",
            shoppingCategory: "Gaming",
            searchTemplates: ["best {item}", "{item} review", "{item} guide", "{item} tips"],
            searchItems: ["gaming headset", "mechanical keyboard", "game recommendations", "PC build guide", "gaming monitor 4k", "controller comparison", "indie games", "gaming desk setup", "stream setup"],
            shoppingTerms: ["gaming mouse", "mechanical keyboard", "gaming headset", "mouse pad large", "gaming chair", "webcam 1080p"],
            videoQueries: ["best games this year", "PC build guide", "gaming setup tour", "indie game reviews", "game design explained"]
        ),
        Bundle(
            interest: "gardening",
            shoppingCategory: "Garden & Outdoor",
            searchTemplates: ["how to {item}", "best {item} for garden", "{item} growing guide", "{item} tips"],
            searchItems: ["raised bed garden", "composting at home", "tomato growing tips", "indoor herb garden", "native plants", "pruning roses", "seed starting", "vegetable garden plan", "soil amendment"],
            shoppingTerms: ["garden hose expandable", "pruning shears", "raised bed kit", "seed starting tray", "compost bin", "garden gloves"],
            videoQueries: ["raised bed garden tutorial", "composting beginners", "growing tomatoes tips", "herb garden indoors", "fall garden prep"]
        ),
        Bundle(
            interest: "music",
            shoppingCategory: "Musical Instruments",
            searchTemplates: ["how to {item}", "best {item} for beginners", "{item} tutorial", "{item} techniques"],
            searchItems: ["guitar chords beginner", "music theory basics", "home recording setup", "piano lessons online", "ukulele songs easy", "ear training", "songwriting tips", "audio interface", "mixing basics"],
            shoppingTerms: ["guitar tuner", "guitar capo", "audio interface USB", "studio headphones", "condenser microphone", "guitar strings"],
            videoQueries: ["guitar lessons beginners", "music theory explained", "home recording studio setup", "piano tutorial easy songs", "mixing mastering basics"]
        ),
        Bundle(
            interest: "travel",
            shoppingCategory: "Travel Gear",
            searchTemplates: ["best {item}", "{item} travel guide", "how to {item}", "{item} on a budget"],
            searchItems: ["travel packing list", "budget flights", "travel insurance compare", "carry on luggage", "travel credit card points", "solo travel tips", "road trip planner", "hostel vs hotel"],
            shoppingTerms: ["carry on luggage", "packing cubes", "travel adapter universal", "neck pillow travel", "portable charger"],
            videoQueries: ["travel packing tips", "budget travel guide", "solo travel beginners", "road trip essentials", "travel vlog tips"]
        ),
        Bundle(
            interest: "coffee",
            shoppingCategory: "Coffee & Tea",
            searchTemplates: ["best {item}", "how to {item}", "{item} guide", "{item} vs"],
            searchItems: ["pour over coffee", "espresso machine home", "coffee grinder burr", "cold brew recipe", "french press technique", "coffee beans roasted", "latte art", "aeropress", "coffee water ratio"],
            shoppingTerms: ["coffee grinder burr", "pour over dripper", "gooseneck kettle", "coffee scale", "french press", "aeropress"],
            videoQueries: ["pour over coffee tutorial", "espresso at home beginner", "cold brew recipe", "latte art tutorial", "coffee grinder comparison"]
        ),
        Bundle(
            interest: "cycling",
            shoppingCategory: "Cycling",
            searchTemplates: ["best {item}", "{item} for beginners", "how to {item}", "{item} review"],
            searchItems: ["road bike vs gravel", "bike maintenance", "cycling routes near me", "bike fit guide", "cycling nutrition", "tubeless tires", "bike commuting tips", "cycling training plan"],
            shoppingTerms: ["bike helmet", "cycling shorts padded", "bike lights", "bike phone mount", "cycling gloves", "tire pump portable"],
            videoQueries: ["bike maintenance basics", "cycling tips beginners", "road bike buying guide", "cycling training plan", "bike commuting tips"]
        ),
        Bundle(
            interest: "reading",
            shoppingCategory: "Books",
            searchTemplates: ["best {item}", "{item} recommendations", "top {item} books", "{item} reading list"],
            searchItems: ["book recommendations fiction", "best nonfiction", "science fiction novels", "book club picks", "audiobooks vs reading", "speed reading tips", "mystery novels", "literary fiction", "memoir recommendations"],
            shoppingTerms: ["book light reading", "kindle paperwhite", "bookshelf floating", "reading glasses", "bookmark set"],
            videoQueries: ["book recommendations", "best books to read", "bookshelf tour", "reading tips habits", "audiobook recommendations"]
        ),
        Bundle(
            interest: "tech gadgets",
            shoppingCategory: "Electronics",
            searchTemplates: ["best {item}", "{item} review", "{item} comparison", "{item} setup guide"],
            searchItems: ["smart home setup", "best laptop for work", "wireless earbuds", "4k monitor", "VPN comparison", "mechanical keyboard", "USB-C hub", "NAS storage", "mesh wifi router"],
            shoppingTerms: ["USB-C hub", "wireless earbuds", "webcam 4k", "external SSD", "laptop stand", "cable management"],
            videoQueries: ["smart home setup guide", "best tech gadgets", "laptop buying guide", "desk setup tour", "home network setup"]
        ),
        Bundle(
            interest: "arts and crafts",
            shoppingCategory: "Art Supplies",
            searchTemplates: ["how to {item}", "{item} for beginners", "best {item} supplies", "{item} tutorial"],
            searchItems: ["watercolor painting", "pottery at home", "knitting patterns", "candle making", "resin art", "calligraphy", "embroidery", "linocut printing", "macrame"],
            shoppingTerms: ["watercolor set", "knitting needles", "calligraphy pen set", "polymer clay", "embroidery kit", "sketch pad"],
            videoQueries: ["watercolor painting tutorial", "beginner pottery", "knitting beginners", "calligraphy basics", "DIY crafts at home"]
        ),
    ]

    private static let allNewsSites: [(String, String, String)] = [
        ("Ars Technica", "https://arstechnica.com", "tech"),
        ("The Verge", "https://www.theverge.com", "tech"),
        ("Wired", "https://www.wired.com", "tech"),
        ("TechCrunch", "https://techcrunch.com", "tech"),
        ("NPR", "https://www.npr.org", "news"),
        ("Reuters", "https://www.reuters.com", "news"),
        ("BBC News", "https://www.bbc.com/news", "news"),
        ("Associated Press", "https://apnews.com", "news"),
        ("The Guardian", "https://www.theguardian.com", "news"),
        ("Serious Eats", "https://www.seriouseats.com", "hobby"),
        ("AllTrails", "https://www.alltrails.com", "hobby"),
        ("PetaPixel", "https://petapixel.com", "hobby"),
        ("Instructables", "https://www.instructables.com", "hobby"),
        ("Lifehacker", "https://lifehacker.com", "hobby"),
        ("Wirecutter", "https://www.nytimes.com/wirecutter", "review"),
        ("HubSpot Blog", "https://blog.hubspot.com", "professional"),
        ("Harvard Business Review", "https://hbr.org", "professional"),
        ("Medium", "https://medium.com", "general"),
        ("Smithsonian Magazine", "https://www.smithsonianmag.com", "general"),
        ("Atlas Obscura", "https://www.atlasobscura.com", "general"),
    ]
}
