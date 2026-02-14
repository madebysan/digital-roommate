import Cocoa
import Combine

// Main app delegate — manages lifecycle, App Nap prevention, and coordinates
// between the status bar UI, module registry, and browsing engine.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var moduleRegistry: ModuleRegistry!
    private var scheduler: Scheduler!
    private var browsingEngine: BrowsingEngine!
    private var activityToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon (LSUIElement = true in Info.plist)
        NSApp.setActivationPolicy(.accessory)

        // Prevent App Nap from throttling our background browsing
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Digital Roommate background browsing"
        )

        // Initialize core systems
        browsingEngine = BrowsingEngine()
        moduleRegistry = ModuleRegistry(engine: browsingEngine)
        scheduler = Scheduler(registry: moduleRegistry)

        // Set up the menu bar UI
        statusBarController = StatusBarController(
            registry: moduleRegistry,
            scheduler: scheduler
        )

        // Start the scheduler
        scheduler.start()

        ActivityLog.shared.log(module: "Core", action: "App launched")
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
}
