import Cocoa

// Coordinates a test run: loads config, sets up mocks, runs the scheduler,
// then flushes logs and prints a summary.
class TestRunner {

    @MainActor
    func run(configPath: String) async -> Bool {
        print("=== Digital Roommate Test Mode ===")
        print("Config: \(configPath)")
        print("")

        // 1. Load the test config
        guard let config = TestConfig.load(from: configPath) else {
            print("[ERROR] Failed to load test config from: \(configPath)")
            return false
        }

        print("Persona: \(config.personaName)")
        print("Cycles: \(config.totalCycles)")
        print("Tick interval: \(config.tickIntervalSeconds)s")
        print("")

        // 2. Install the test persona
        TestPersonas.install()

        // 3. Override settings with the test config's settings
        SettingsManager.shared.apply(config.settings)

        // Make sure the active persona matches the test config
        SettingsManager.shared.update { settings in
            settings.activePersonaName = config.personaName
        }

        // 4. Clear any existing activity log for a clean test
        let logPath = ActivityLog.shared.logFilePath
        try? FileManager.default.removeItem(at: logPath)

        // 5. Set up the browsing engine with mock web views
        let engine = BrowsingEngine()
        engine.webViewFactory = { moduleId in
            MockWebViewInstance(moduleId: moduleId, userAgent: "MockAgent/1.0", stealthScripts: [])
        }

        // 6. Set up the module registry
        let registry = ModuleRegistry(engine: engine)

        // Apply module enabled/disabled state from config
        for module in registry.allModules {
            let shouldEnable: Bool
            switch module.id {
            case "search":   shouldEnable = config.settings.searchEnabled
            case "shopping": shouldEnable = config.settings.shoppingEnabled
            case "video":    shouldEnable = config.settings.videoEnabled
            case "news":     shouldEnable = config.settings.newsEnabled
            default:         shouldEnable = false
            }
            module.isEnabled = shouldEnable
        }

        let enabledModules = registry.allModules.filter { $0.isEnabled }.map { $0.id }
        print("Enabled modules: \(enabledModules.joined(separator: ", "))")
        print("")

        // 7. Set up the scheduler with test timing
        let scheduler = Scheduler(registry: registry)
        scheduler.tickInterval = config.tickIntervalSeconds
        scheduler.maxCycles = config.totalCycles
        scheduler.testMode = true

        // 8. Run the scheduler — it will stop after maxCycles ticks
        print("Starting test run...")
        scheduler.start()

        // Wait for the scheduler to finish all cycles
        // Poll until it stops (maxCycles will trigger stop())
        while scheduler.isRunning {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s poll
        }

        // Give any in-flight module tasks time to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s

        // 9. Flush the activity log
        ActivityLog.shared.flush()

        // 10. Print summary
        print("")
        print("=== Test Run Complete ===")

        // Count log entries
        if let data = try? Data(contentsOf: logPath),
           let entries = try? JSONDecoder().decode([ActivityLog.Entry].self, from: data) {
            print("Total log entries: \(entries.count)")

            // Count by module
            var moduleCounts: [String: Int] = [:]
            for entry in entries {
                moduleCounts[entry.module, default: 0] += 1
            }
            for (module, count) in moduleCounts.sorted(by: { $0.key < $1.key }) {
                print("  \(module): \(count) entries")
            }

            // Count by action
            var actionCounts: [String: Int] = [:]
            for entry in entries {
                actionCounts[entry.action, default: 0] += 1
            }
            print("")
            print("Actions:")
            for (action, count) in actionCounts.sorted(by: { $0.value > $1.value }) {
                print("  \(action): \(count)")
            }
        } else {
            print("No log entries found — check for errors above.")
        }

        print("")
        print("Log file: \(logPath.path)")
        print("Run the analysis script: python3 scripts/analyze-log.py \(logPath.path)")

        return true
    }
}
