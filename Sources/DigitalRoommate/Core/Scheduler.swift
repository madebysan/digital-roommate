import Foundation
import Combine

// Timer-based scheduler that decides when each module should run.
// Uses time-of-day awareness and Poisson-distributed intervals to
// create realistic-looking browsing patterns.
class Scheduler {

    private let registry: ModuleRegistry
    private var timer: AnyCancellable?
    private var moduleTasks: [String: Task<Void, Never>] = [:]
    private var nextRunTime: [String: Date] = [:]
    private(set) var isRunning = false

    // Time blocks that determine activity levels throughout the day
    enum TimeBlock: String {
        case morning    // 6 AM - 12 PM — moderate activity
        case afternoon  // 12 PM - 6 PM — high activity
        case evening    // 6 PM - 11 PM — moderate activity
        case lateNight  // 11 PM - 1 AM — low activity
        case vampire    // 1 AM - 5 AM  — very low (but present) activity
        case earlyMorn  // 5 AM - 6 AM  — minimal activity

        // Average minutes between module executions for this time block
        var avgIntervalMinutes: Double {
            switch self {
            case .morning:    return 8
            case .afternoon:  return 5
            case .evening:    return 10
            case .lateNight:  return 20
            case .vampire:    return 30
            case .earlyMorn:  return 45
            }
        }

        // Whether this is a weekend day affects the schedule
        func adjustedInterval(isWeekend: Bool) -> Double {
            if isWeekend {
                switch self {
                case .morning:    return 15   // sleep in on weekends
                case .afternoon:  return 6
                case .evening:    return 8
                case .lateNight:  return 15
                case .vampire:    return 25
                case .earlyMorn:  return 60
                }
            }
            return avgIntervalMinutes
        }

        static func current() -> TimeBlock {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 6..<12:  return .morning
            case 12..<18: return .afternoon
            case 18..<23: return .evening
            case 23, 0:   return .lateNight
            case 1..<5:   return .vampire
            case 5..<6:   return .earlyMorn
            default:      return .lateNight
            }
        }
    }

    init(registry: ModuleRegistry) {
        self.registry = registry
    }

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Schedule initial run times for all modules
        for module in registry.allModules where module.isEnabled {
            scheduleNext(for: module.id)
        }

        // Check every 30 seconds which modules are due to run
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }

        ActivityLog.shared.log(module: "Scheduler", action: "Started (time block: \(TimeBlock.current().rawValue))")
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil

        // Cancel all running module tasks
        for (_, task) in moduleTasks {
            task.cancel()
        }
        moduleTasks.removeAll()
        nextRunTime.removeAll()

        ActivityLog.shared.log(module: "Scheduler", action: "Stopped")
    }

    /// Returns the next scheduled time for a module, or nil if not scheduled
    func nextRun(for moduleId: String) -> Date? {
        return nextRunTime[moduleId]
    }

    /// Current time block name for display
    var currentTimeBlock: String {
        return TimeBlock.current().rawValue
    }

    // MARK: - Private

    private func tick() {
        let now = Date()

        for module in registry.allModules {
            // Skip disabled modules
            guard module.isEnabled else {
                // Cancel if it was running
                if let task = moduleTasks[module.id] {
                    task.cancel()
                    moduleTasks.removeValue(forKey: module.id)
                }
                continue
            }

            // Skip if not yet time
            if let nextTime = nextRunTime[module.id], now < nextTime {
                continue
            }

            // Skip if already running
            if module.isActive {
                continue
            }

            // Time to run this module
            let task = Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Try to get a web view from the pool
                guard let webView = self.registry.engine.acquireWebView(for: module.id) else {
                    // Pool full — try again next tick
                    self.scheduleNext(for: module.id, delayMinutes: 1)
                    return
                }

                ActivityLog.shared.log(module: module.id, action: "Starting session")

                // Let the module do its thing
                await module.execute(webView: webView)

                // Release the web view back to the pool
                self.registry.engine.releaseWebView(for: module.id)

                // Schedule the next run
                self.scheduleNext(for: module.id)

                ActivityLog.shared.log(module: module.id, action: "Session complete (\(module.actionsCompleted) actions)")
            }

            moduleTasks[module.id] = task
        }
    }

    /// Schedule the next run for a module using Poisson-distributed timing.
    /// Poisson distribution means intervals vary naturally — sometimes short,
    /// sometimes long — which looks more human than fixed intervals.
    private func scheduleNext(for moduleId: String, delayMinutes: Double? = nil) {
        let delay: Double

        if let fixed = delayMinutes {
            delay = fixed
        } else {
            let timeBlock = TimeBlock.current()
            let isWeekend = Calendar.current.isDateInWeekend(Date())
            let avgInterval = timeBlock.adjustedInterval(isWeekend: isWeekend)

            // Poisson-distributed delay: -ln(U) * mean, where U is uniform(0,1)
            // This gives exponentially distributed inter-arrival times
            let u = Double.random(in: 0.001...0.999)
            delay = -log(u) * avgInterval
        }

        let nextTime = Date().addingTimeInterval(delay * 60)
        nextRunTime[moduleId] = nextTime
    }
}
