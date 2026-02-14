import Cocoa
import Combine

// Main app delegate — manages lifecycle, App Nap prevention, and coordinates
// between the status bar UI, module registry, and browsing engine.
// Gates the scheduler behind onboarding on first launch.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var moduleRegistry: ModuleRegistry!
    private var scheduler: Scheduler!
    private var browsingEngine: BrowsingEngine!
    private var activityToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // Window controllers held here so they stay alive
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon (LSUIElement = true in Info.plist)
        NSApp.setActivationPolicy(.accessory)

        // Prevent App Nap from throttling our background browsing
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Digital Roommate background browsing"
        )

        // Migrate old persona.json → personas/ directory, ensure at least one exists
        Persona.migrateIfNeeded()
        Persona.ensureDefaultExists()

        // Initialize core systems
        browsingEngine = BrowsingEngine()
        moduleRegistry = ModuleRegistry(engine: browsingEngine)
        scheduler = Scheduler(registry: moduleRegistry)

        // Sync module enabled state from settings
        syncModulesFromSettings()

        // Set up the menu bar UI (visible during onboarding too)
        statusBarController = StatusBarController(
            registry: moduleRegistry,
            scheduler: scheduler
        )

        ActivityLog.shared.log(module: "Core", action: "App launched")

        // Onboarding gate: only start the scheduler after onboarding completes
        if OnboardingWindowController.hasCompletedOnboarding {
            scheduler.start()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop all modules gracefully
        scheduler.stop()
        moduleRegistry.stopAll()

        // Release App Nap prevention
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }

        ActivityLog.shared.log(module: "Core", action: "App terminated")
        ActivityLog.shared.flush()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let controller = OnboardingWindowController()
        controller.onComplete = { [weak self] in
            guard let self = self else { return }
            // Apply module toggles from onboarding to the registry
            self.syncModulesFromSettings()
            // Now start the scheduler
            self.scheduler.start()
            self.statusBarController.rebuildMenu()
            self.onboardingController = nil
            ActivityLog.shared.log(module: "Core", action: "Onboarding completed, scheduler started")
        }
        controller.show()
        onboardingController = controller
    }

    // MARK: - Settings Sync

    /// Syncs module enabled/disabled state from AppSettings to ModuleRegistry
    private func syncModulesFromSettings() {
        let settings = SettingsManager.shared.current
        let mapping: [(String, Bool)] = [
            ("search", settings.searchEnabled),
            ("shopping", settings.shoppingEnabled),
            ("video", settings.videoEnabled),
            ("news", settings.newsEnabled),
        ]
        for (id, enabled) in mapping {
            if let module = moduleRegistry.module(withId: id) {
                module.isEnabled = enabled
            }
        }
    }
}
