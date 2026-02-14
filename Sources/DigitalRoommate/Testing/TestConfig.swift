import Foundation

// Configuration for a test run — loaded from a JSON file.
// Overrides settings and controls how many scheduler cycles to run.
struct TestConfig: Codable {
    let personaName: String          // which test persona to use
    let settings: AppSettings        // override all app settings
    let totalCycles: Int             // how many scheduler ticks to run
    let tickIntervalSeconds: Double  // speed up the scheduler (e.g., 0.1s)

    // Load a TestConfig from a JSON file path
    static func load(from path: String) -> TestConfig? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            print("[TestConfig] Failed to read file: \(path)")
            return nil
        }
        do {
            return try JSONDecoder().decode(TestConfig.self, from: data)
        } catch {
            print("[TestConfig] Failed to decode: \(error)")
            return nil
        }
    }
}
