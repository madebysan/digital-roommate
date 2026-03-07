import SwiftUI

// SwiftUI onboarding wizard (5 steps). Replaces the old AppKit implementation.
// Shows once — controlled by UserDefaults "hasCompletedOnboarding".

struct OnboardingView: View {
    var onComplete: (() -> Void)?

    @State private var currentStep = 0
    @State private var slideDirection: Edge = .trailing

    // User choices
    @State private var moduleToggles: [String: Bool] = [
        "search": true, "shopping": true, "video": true, "news": true
    ]
    @State private var activityLevel: AppSettings.ActivityLevel = .medium
    @State private var personaName: String = Persona.loadDefault().name

    private let totalSteps = 5

    private static let modules: [(String, String, String, String)] = [
        ("search", "magnifyingglass", "Search Noise", "Fake searches on Google, Bing, DuckDuckGo"),
        ("shopping", "cart", "Shopping Noise", "Browses Amazon products and results"),
        ("video", "play.rectangle", "Video Noise", "Watches muted YouTube videos"),
        ("news", "newspaper", "News & Browsing", "Reads news articles, follows links"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            ZStack {
                stepContent
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideDirection).combined(with: .opacity),
                        removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // Bottom bar: dots + buttons
            HStack {
                // Pill dot indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(dotColor(for: i))
                            .frame(width: i == currentStep ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.25), value: currentStep)
                    }
                }

                Spacer()

                // Back button
                if currentStep > 0 {
                    Button("Back") { goBack() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                }

                // Next button
                Button(nextButtonTitle) { goNext() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 560, height: 520)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: welcomeStep
        case 1: modulesStep
        case 2: activityStep
        case 3: personaStep
        case 4: readyStep
        default: EmptyView()
        }
    }

    // MARK: - Welcome (Step 1)

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)

            stepLabel(0)

            Text("Welcome to Digital Roommate")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Digital Roommate creates realistic web traffic from a fake persona, making it look like another person lives in your house. It runs silently in your menu bar \u{2014} search queries, shopping, YouTube, and news reading, all timed to look natural.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Modules (Step 2)

    private var modulesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepLabel(1)

            Text("Choose Your Modules")
                .font(.system(size: 26, weight: .bold))

            Text("Pick which types of decoy traffic to generate. Each module runs independently \u{2014} turn on only what you want.")
                .font(.body)
                .foregroundStyle(.secondary)

            ForEach(Self.modules, id: \.0) { id, icon, name, desc in
                moduleCard(id: id, icon: icon, name: name, description: desc)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private func moduleCard(id: String, icon: String, name: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .medium))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { moduleToggles[id] ?? true },
                set: { moduleToggles[id] = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Activity Level (Step 3)

    private var activityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepLabel(2)

            Text("Activity Level")
                .font(.system(size: 26, weight: .bold))

            Text("This controls how often Digital Roommate opens background browser sessions \u{2014} searches, shopping, video watching, and news reading. Higher levels use more bandwidth.")
                .font(.body)
                .foregroundStyle(.secondary)

            ForEach(AppSettings.ActivityLevel.allCases, id: \.self) { level in
                activityCard(level: level)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private func activityCard(level: AppSettings.ActivityLevel) -> some View {
        let isSelected = level == activityLevel

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activityLevel = level
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(level.displayName).font(.system(size: 15, weight: .medium))
                        Text(level.sessionsPerHour).font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(level.description).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persona (Step 4)

    private var personaStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "theatermasks.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)

            stepLabel(3)

            Text("Your Roommate\u{2019}s Persona")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Your roommate has a fake identity that defines what they search for, shop for, watch, and read. You can customize or randomize the persona anytime in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            // Persona name card
            Text("Current persona: \(personaName)")
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Ready (Step 5)

    private var readyStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.green)
                .symbolEffect(.pulse, options: .nonRepeating)

            stepLabel(4)

            Text("You\u{2019}re All Set")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            // Summary card
            summaryCard

            Text("Digital Roommate will start generating traffic in the background. You can adjust settings anytime from the menu bar icon.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var summaryCard: some View {
        let enabledModules = moduleToggles.filter { $0.value }.map { $0.key }
        let moduleNames = enabledModules.sorted().map { id -> String in
            switch id {
            case "search": return "Search"
            case "shopping": return "Shopping"
            case "video": return "Video"
            case "news": return "News"
            default: return id
            }
        }
        let rows: [(String, String, String)] = [
            ("square.grid.2x2", "Modules", moduleNames.isEmpty ? "None" : moduleNames.joined(separator: ", ")),
            ("gauge.medium", "Activity", activityLevel.displayName),
            ("person.fill", "Persona", personaName),
        ]

        return VStack(spacing: 6) {
            ForEach(rows, id: \.1) { iconName, label, value in
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Text(label)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(value)
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 400)
    }

    // MARK: - Helpers

    private func stepLabel(_ step: Int) -> some View {
        Text("STEP \(step + 1) OF \(totalSteps)")
            .font(.system(size: 11, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }

    private func dotColor(for index: Int) -> Color {
        if index == currentStep {
            return .accentColor
        } else if index < currentStep {
            return .accentColor.opacity(0.4)
        } else {
            return .primary.opacity(0.15)
        }
    }

    private var nextButtonTitle: String {
        let titles = ["Let\u{2019}s Set Up", "Save Modules", "Set Activity", "Got It", "Start Digital Roommate"]
        return titles[currentStep]
    }

    private func goBack() {
        slideDirection = .leading
        withAnimation {
            currentStep -= 1
        }
    }

    private func goNext() {
        if currentStep < totalSteps - 1 {
            slideDirection = .trailing
            withAnimation {
                currentStep += 1
            }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        SettingsManager.shared.update { settings in
            settings.activityLevel = activityLevel
            settings.searchEnabled = moduleToggles["search"] ?? true
            settings.shoppingEnabled = moduleToggles["shopping"] ?? true
            settings.videoEnabled = moduleToggles["video"] ?? true
            settings.newsEnabled = moduleToggles["news"] ?? true
        }

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete?()
    }
}
