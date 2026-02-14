import Cocoa
import Combine
import ServiceManagement

// Manages the menu bar icon and dropdown menu.
// Shows module status, toggles, schedule info, and app controls.
class StatusBarController {

    private var statusItem: NSStatusItem!
    private let registry: ModuleRegistry
    private let scheduler: Scheduler
    private var refreshTimer: AnyCancellable?

    init(registry: ModuleRegistry, scheduler: Scheduler) {
        self.registry = registry
        self.scheduler = scheduler
        setupStatusItem()
        startRefreshTimer()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use a person silhouette icon — looks like a "roommate"
            button.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: "Digital Roommate")
            button.image?.size = NSSize(width: 16, height: 16)
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Digital Roommate", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Status line
        let statusText = scheduler.isRunning
            ? "\(registry.enabledCount) modules active  ·  \(scheduler.currentTimeBlock)"
            : "Paused"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Module toggles
        let modulesHeader = NSMenuItem(title: "Modules", action: nil, keyEquivalent: "")
        modulesHeader.isEnabled = false
        menu.addItem(modulesHeader)

        for module in registry.allModules {
            let item = NSMenuItem(
                title: "\(module.displayName)",
                action: #selector(toggleModule(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = module.id
            item.state = module.isEnabled ? .on : .off

            // Show status as subtitle if active
            if module.isActive {
                item.title = "\(module.displayName) — \(module.statusText)"
            }

            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Scheduler controls
        if scheduler.isRunning {
            menu.addItem(withTitle: "Pause All", action: #selector(pauseAll), keyEquivalent: "p").target = self
        } else {
            menu.addItem(withTitle: "Resume All", action: #selector(resumeAll), keyEquivalent: "p").target = self
        }

        menu.addItem(.separator())

        // Launch at Login toggle
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        menu.addItem(loginItem)

        // Open activity log
        menu.addItem(withTitle: "Show Activity Log...", action: #selector(showActivityLog), keyEquivalent: "l").target = self

        menu.addItem(.separator())

        // Quit
        menu.addItem(withTitle: "Quit Digital Roommate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        self.statusItem.menu = menu
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        // Rebuild the menu every 10 seconds to show current status
        refreshTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
    }

    // MARK: - Actions

    @objc private func toggleModule(_ sender: NSMenuItem) {
        guard let moduleId = sender.representedObject as? String else { return }
        registry.toggleModule(moduleId)
        rebuildMenu()
    }

    @objc private func pauseAll() {
        scheduler.stop()
        registry.stopAll()
        rebuildMenu()
        ActivityLog.shared.log(module: "UI", action: "All modules paused by user")
    }

    @objc private func resumeAll() {
        scheduler.start()
        rebuildMenu()
        ActivityLog.shared.log(module: "UI", action: "All modules resumed by user")
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let newValue = !current

        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
        } catch {
            ActivityLog.shared.log(module: "UI", action: "Launch at Login failed: \(error.localizedDescription)")
        }

        rebuildMenu()
    }

    @objc private func showActivityLog() {
        let logPath = ActivityLog.shared.logFilePath
        NSWorkspace.shared.open(logPath)
    }
}
