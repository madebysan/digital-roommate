import Cocoa

// Digital Roommate — macOS menu bar app that generates realistic web traffic
// from fake personas to poison ISP-level and data-broker profiling.

// Check for --test-mode <config.json> CLI argument
if let testIndex = CommandLine.arguments.firstIndex(of: "--test-mode"),
   testIndex + 1 < CommandLine.arguments.count {
    let configPath = CommandLine.arguments[testIndex + 1]
    let app = NSApplication.shared

    // Test mode: run the test runner instead of the normal app UI
    Task { @MainActor in
        let runner = TestRunner()
        let success = await runner.run(configPath: configPath)
        exit(success ? 0 : 1)
    }

    app.run()
} else {
    // Normal app launch
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
