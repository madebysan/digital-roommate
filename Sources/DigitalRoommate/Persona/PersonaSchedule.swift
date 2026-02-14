import Foundation

// Manages persona-aware scheduling decisions.
// The persona's active hours influence when modules run and how intensely.
struct PersonaSchedule {

    let persona: Persona

    /// Whether the persona should be active right now, based on time of day
    /// and the persona's active hours preferences.
    func shouldBeActive() -> Bool {
        let weight = currentWeight()
        // Use the weight as a probability — higher weight = more likely to be active
        return Double.random(in: 0...1) < weight
    }

    /// Get the activity weight for the current time block
    func currentWeight() -> Double {
        let timeBlock = Scheduler.TimeBlock.current()
        switch timeBlock {
        case .morning, .earlyMorn:
            return persona.activeHours.morningWeight
        case .afternoon:
            return persona.activeHours.afternoonWeight
        case .evening:
            return persona.activeHours.eveningWeight
        case .lateNight:
            return persona.activeHours.lateNightWeight
        case .vampire:
            return persona.activeHours.vampireWeight
        }
    }
}
