import Cocoa
import Combine

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
            button.image?.size = NSSize(width: Styles.statusBarIconSize, height: Styles.statusBarIconSize)
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Digital Roommate", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Status line
        let statusText = scheduler.isRunning
            ? "\(registry.enabledCount) modules active  \u{00B7}  \(scheduler.currentTimeBlock)"
            : "Paused"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Module toggles
        let modulesHeader = NSMenuItem(title: "Modules", action: nil, keyEquivalent: "")
        modulesHeader.isEnabled = false
        menu.addItem(modulesHeader)

        // Map module IDs to SF Symbol names for menu icons
        let moduleIcons: [String: String] = [
            "search": "magnifyingglass",
            "shopping": "cart",
            "video": "play.rectangle",
            "news": "newspaper",
        ]

        for module in registry.allModules {
            let item = NSMenuItem(
                title: "\(module.displayName)",
                action: #selector(toggleModule(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = module.id
            item.state = module.isEnabled ? .on : .off

            // Add SF Symbol icon
            if let iconName = moduleIcons[module.id],
               let img = NSImage(systemSymbolName: iconName, accessibilityDescription: module.displayName) {
                let config = NSImage.SymbolConfiguration(pointSize: Styles.sidebarIconSize, weight: .regular)
                item.image = img.withSymbolConfiguration(config)
            }

            // Show status as subtitle if active
            if module.isActive {
                item.title = "\(module.displayName) \u{2014} \(module.statusText)"
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

        // Settings
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",").target = self

        menu.addItem(.separator())

        // About & Onboarding
        menu.addItem(withTitle: "About Digital Roommate\u{2026}", action: #selector(openAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Onboarding Guide\u{2026}", action: #selector(openOnboarding), keyEquivalent: "").target = self

        // Open activity log
        menu.addItem(withTitle: "Show Activity Log\u{2026}", action: #selector(showActivityLog), keyEquivalent: "l").target = self

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

        // Also sync the toggle to AppSettings so it persists
        SettingsManager.shared.update { settings in
            switch moduleId {
            case "search":   settings.searchEnabled = sender.state != .on
            case "shopping": settings.shoppingEnabled = sender.state != .on
            case "video":    settings.videoEnabled = sender.state != .on
            case "news":     settings.newsEnabled = sender.state != .on
            default: break
            }
        }

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

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout() {
        HelpWindowController.shared.show()
    }

    @objc private func openOnboarding() {
        let onboarding = OnboardingWindowController()
        onboarding.show()
        // Keep a strong reference so the window stays alive
        objc_setAssociatedObject(self, "onboarding", onboarding, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private func showActivityLog() {
        let logPath = ActivityLog.shared.logFilePath
        NSWorkspace.shared.open(logPath)
    }
}
