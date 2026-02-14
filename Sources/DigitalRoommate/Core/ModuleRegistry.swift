import Foundation

// Central registry of all browsing modules.
// Manages module lifecycle and persists enabled/disabled state.
class ModuleRegistry {

    let engine: BrowsingEngine
    private(set) var allModules: [BrowsingModule] = []

    init(engine: BrowsingEngine) {
        self.engine = engine
        registerModules()
        loadEnabledState()
    }

    private func registerModules() {
        // Create all modules — they start disabled until state is loaded
        allModules = [
            SearchNoiseModule(),
            ShoppingNoiseModule(),
            VideoNoiseModule(),
            NewsModule()
        ]
    }

    // MARK: - Public API

    /// Get a module by ID
    func module(withId id: String) -> BrowsingModule? {
        return allModules.first { $0.id == id }
    }

    /// Toggle a module on/off
    func toggleModule(_ id: String) {
        guard let module = module(withId: id) else { return }
        module.isEnabled.toggle()
        saveEnabledState()

        if !module.isEnabled {
            module.stop()
        }

        ActivityLog.shared.log(
            module: id,
            action: module.isEnabled ? "Enabled" : "Disabled"
        )
    }

    /// Stop all modules
    func stopAll() {
        for module in allModules {
            module.stop()
        }
    }

    /// Number of enabled modules
    var enabledCount: Int {
        return allModules.filter { $0.isEnabled }.count
    }

    // MARK: - State Persistence

    private func saveEnabledState() {
        var state: [String: Bool] = [:]
        for module in allModules {
            state[module.id] = module.isEnabled
        }
        UserDefaults.standard.set(state, forKey: "moduleEnabledState")
    }

    private func loadEnabledState() {
        // Default: all modules enabled on first launch
        guard let state = UserDefaults.standard.dictionary(forKey: "moduleEnabledState") as? [String: Bool] else {
            for module in allModules {
                module.isEnabled = true
            }
            return
        }

        for module in allModules {
            module.isEnabled = state[module.id] ?? true
        }
    }
}
