import Foundation

// Protocol that all browsing modules must implement.
// Each module represents a type of fake browsing activity (search, shopping, video, news).
protocol BrowsingModule: AnyObject {
    // Unique identifier for this module (e.g., "search", "shopping")
    var id: String { get }

    // Human-readable name for the UI
    var displayName: String { get }

    // Whether this module is currently enabled by the user
    var isEnabled: Bool { get set }

    // Whether this module is currently running a browsing session
    var isActive: Bool { get }

    // Status text for the menu bar (e.g., "Idle", "Searching: best hiking boots 2024")
    var statusText: String { get }

    // Number of actions completed in the current session
    var actionsCompleted: Int { get }

    // Called by the scheduler when it's time for this module to do work.
    // The module should use the provided WebViewInstance to browse.
    func execute(webView: WebViewInstance) async

    // Called when the module should stop its current activity
    func stop()
}
