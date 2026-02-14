import Foundation

// Handles reading and writing JSON state files to Application Support.
// All persistent data (activity logs, persona overrides, module state)
// lives in ~/Library/Application Support/DigitalRoommate/
struct StateStore {

    static let appSupportDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DigitalRoommate")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        return dir
    }()

    /// Read a Codable value from a JSON file in Application Support
    static func load<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        let url = appSupportDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Write a Codable value to a JSON file in Application Support
    static func save<T: Codable>(_ value: T, to filename: String) {
        let url = appSupportDirectory.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Activity Log

// Logs all module activity to a JSON file for inspection.
// Append-only log with timestamps — useful for verifying the app is working.
// Each entry carries structured metadata so you can see exactly what happened:
// which URL was loaded, what query was searched, which engine was used, etc.
class ActivityLog {

    static let shared = ActivityLog()

    struct Entry: Codable {
        let timestamp: String
        let module: String
        let action: String
        // Structured context — every key/value pair relevant to this event.
        // Common keys: url, query, engine, pageTitle, searchTerm, siteName,
        // productTitle, videoTitle, watchDurationSec, videoDurationSec,
        // sessionType, actionsCompleted, timeBlock, activityLevel, error
        let metadata: [String: String]?
    }

    private var buffer: [Entry] = []
    private let bufferLimit = 5
    private let maxEntries = 5000
    private let filename = "activity-log.json"

    var logFilePath: URL {
        return StateStore.appSupportDirectory.appendingPathComponent(filename)
    }

    /// Add a log entry with optional structured metadata. Flushes to disk periodically.
    func log(module: String, action: String, metadata: [String: String]? = nil) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withTimeZone]

        let entry = Entry(
            timestamp: formatter.string(from: Date()),
            module: module,
            action: action,
            metadata: metadata
        )

        buffer.append(entry)

        // Console output includes metadata for debugging
        var line = "[\(entry.timestamp)] [\(module)] \(action)"
        if let meta = metadata, !meta.isEmpty {
            let pairs = meta.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            line += " | \(pairs)"
        }
        print(line)

        if buffer.count >= bufferLimit {
            flush()
        }
    }

    /// Write buffered entries to disk
    func flush() {
        guard !buffer.isEmpty else { return }

        // Load existing entries
        var entries = StateStore.load([Entry].self, from: filename) ?? []

        // Append new entries
        entries.append(contentsOf: buffer)
        buffer.removeAll()

        // Trim to max size (keep most recent)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }

        StateStore.save(entries, to: filename)
    }
}
