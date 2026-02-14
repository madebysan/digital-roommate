import Cocoa

// Digital Roommate — macOS menu bar app that generates realistic web traffic
// from fake personas to poison ISP-level and data-broker profiling.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
