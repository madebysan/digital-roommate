import Foundation
import ServiceManagement

// Singleton that owns the current AppSettings.
// Persists as JSON in UserDefaults. Modules read `SettingsManager.shared.current`
// at the start of each execute() — no reactive observation needed.
class SettingsManager {

    static let shared = SettingsManager()

    private static let storageKey = "appSettings"

    // The live settings — read by modules, written by UI
    private(set) var current: AppSettings

    private init() {
        current = SettingsManager.load() ?? AppSettings()
    }

    // MARK: - Read / Write

    /// Update settings and persist immediately.
    func update(_ transform: (inout AppSettings) -> Void) {
        transform(&current)
        save()
    }

    /// Replace settings wholesale (used by onboarding).
    func apply(_ settings: AppSettings) {
        current = settings
        save()
        syncLaunchAtLogin()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func load() -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    // MARK: - Launch at Login

    /// Syncs the launchAtLogin setting with SMAppService.
    func syncLaunchAtLogin() {
        let shouldLaunch = current.launchAtLogin
        do {
            if shouldLaunch {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            ActivityLog.shared.log(module: "Settings", action: "Launch at Login sync failed", metadata: [
                "error": error.localizedDescription,
                "desiredState": shouldLaunch ? "enabled" : "disabled",
            ])
        }
    }
}
