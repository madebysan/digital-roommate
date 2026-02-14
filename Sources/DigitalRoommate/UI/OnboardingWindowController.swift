import Cocoa

// First-run onboarding wizard (4 steps).
// Shows once — controlled by UserDefaults "hasCompletedOnboarding".
// The scheduler does NOT start until the user clicks "Get Started".
class OnboardingWindowController: NSWindowController {

    // Callback fired when the user finishes onboarding
    var onComplete: (() -> Void)?

    private var currentStep = 0
    private let totalSteps = 5

    // User choices tracked across steps
    private var moduleToggles: [String: Bool] = [
        "search": true, "shopping": true, "video": true, "news": true
    ]
    private var activityLevel: AppSettings.ActivityLevel = .medium

    // UI elements
    private var contentContainer: NSView!
    private var backButton: NSButton!
    private var nextButton: NSButton!
    private var dotStack: NSStackView!

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Styles.onboardingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Digital Roommate"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupLayout()
        showStep(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    static var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func show() {
        currentStep = 0
        showStep(0)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout

    private func setupLayout() {
        guard let contentView = window?.contentView else { return }

        // Main content area
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentContainer)

        // Bottom bar: dots + buttons
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomBar)

        // Dot indicators
        dotStack = NSStackView()
        dotStack.orientation = .horizontal
        dotStack.spacing = 8
        dotStack.translatesAutoresizingMaskIntoConstraints = false

        for i in 0..<totalSteps {
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = (i == 0 ? Styles.accentColor : Styles.tertiaryLabel).cgColor
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            dotStack.addArrangedSubview(dot)
        }

        bottomBar.addSubview(dotStack)

        // Navigation buttons
        backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .rounded
        bottomBar.addSubview(backButton)

        nextButton = NSButton(title: "Continue", target: self, action: #selector(goNext))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        bottomBar.addSubview(nextButton)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Styles.windowPadding),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Styles.windowPadding),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            bottomBar.heightAnchor.constraint(equalToConstant: 36),

            dotStack.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            dotStack.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            nextButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            nextButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            backButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -8),
            backButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])
    }

    // MARK: - Step Navigation

    private func showStep(_ step: Int) {
        currentStep = step

        // Clear previous content
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        // Build step content
        let stepView: NSView
        switch step {
        case 0: stepView = buildWelcomeStep()
        case 1: stepView = buildModulesStep()
        case 2: stepView = buildActivityStep()
        case 3: stepView = buildPersonaStep()
        case 4: stepView = buildReadyStep()
        default: return
        }

        stepView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stepView)
        NSLayoutConstraint.activate([
            stepView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: Styles.windowPadding),
            stepView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: Styles.windowPadding),
            stepView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -Styles.windowPadding),
        ])

        // Update dots
        for (i, dot) in dotStack.arrangedSubviews.enumerated() {
            dot.layer?.backgroundColor = (i == step ? Styles.accentColor : Styles.tertiaryLabel).cgColor
        }

        // Update buttons
        backButton.isHidden = step == 0
        nextButton.title = step == totalSteps - 1 ? "Get Started" : "Continue"
    }

    @objc private func goBack() {
        if currentStep > 0 {
            showStep(currentStep - 1)
        }
    }

    @objc private func goNext() {
        if currentStep < totalSteps - 1 {
            showStep(currentStep + 1)
        } else {
            finishOnboarding()
        }
    }

    // MARK: - Step 1: Welcome

    private func buildWelcomeStep() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "person.fill.viewfinder", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .light)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = Styles.accentColor
        }
        stack.addArrangedSubview(iconView)

        let title = Styles.label("Welcome to Digital Roommate", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let body = Styles.label(
            "Digital Roommate creates realistic web traffic from a fake persona. " +
            "Your ISP and data brokers see traffic that looks like another person lives " +
            "in your house \u{2014} diluting your real browsing profile with convincing decoy activity.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(body)

        let detail = Styles.label(
            "The app runs silently in your menu bar, generating search queries, shopping " +
            "sessions, YouTube watching, and news reading \u{2014} all timed to look natural.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(detail)

        return stack
    }

    // MARK: - Step 2: Modules

    private func buildModulesStep() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let title = Styles.label("Choose Your Modules", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let subtitle = Styles.label(
            "Pick which types of decoy traffic to generate. Each module runs independently \u{2014} turn on only what you want.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(subtitle)

        let modules: [(String, String, String, String)] = [
            ("search", "magnifyingglass", "Search Noise", "Fake searches on Google, Bing, DuckDuckGo"),
            ("shopping", "cart", "Shopping Noise", "Browses Amazon products and results"),
            ("video", "play.rectangle", "Video Noise", "Watches muted YouTube videos"),
            ("news", "newspaper", "News & Browsing", "Reads news articles, follows links"),
        ]

        for (id, icon, name, desc) in modules {
            let card = makeModuleCard(id: id, icon: icon, name: name, description: desc)
            stack.addArrangedSubview(card)

            // Make the card fill width
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: Styles.onboardingSize.width - Styles.windowPadding * 2).isActive = true
        }

        return stack
    }

    private func makeModuleCard(id: String, icon: String, name: String, description: String) -> NSView {
        // Use a plain NSView with a background layer as the card container.
        // NSBox.contentView replacement doesn't propagate intrinsic size properly.
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = Styles.cardBackground.cgColor
        card.layer?.cornerRadius = Styles.cardCornerRadius
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = Styles.separator.withAlphaComponent(0.3).cgColor

        // Icon (fixed size)
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: name) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = Styles.accentColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        // Text column: name + description stacked vertically
        let nameLabel = Styles.label(name, font: Styles.headlineFont)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let descLabel = Styles.label(description, font: Styles.captionFont, color: Styles.secondaryLabel)
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = NSStackView(views: [nameLabel, descLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        // Toggle (fixed size)
        let toggle = NSSwitch()
        toggle.state = moduleToggles[id] == true ? .on : .off
        toggle.target = self
        toggle.action = #selector(moduleToggled(_:))
        toggle.controlSize = .small
        toggle.setContentHuggingPriority(.required, for: .horizontal)

        let tagMap = ["search": 0, "shopping": 1, "video": 2, "news": 3]
        toggle.tag = 900 + (tagMap[id] ?? 0)

        // Horizontal row: icon | text | toggle
        let row = NSStackView(views: [iconView, textStack, toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
        ])

        return card
    }

    @objc private func moduleToggled(_ sender: NSSwitch) {
        let ids = ["search", "shopping", "video", "news"]
        let index = sender.tag - 900
        guard index >= 0, index < ids.count else { return }
        moduleToggles[ids[index]] = sender.state == .on
    }

    // MARK: - Step 3: Activity Level

    private func buildActivityStep() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12

        let title = Styles.label("Activity Level", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let subtitle = Styles.label(
            "This controls how often Digital Roommate opens background browser sessions \u{2014} " +
            "searches, shopping, video watching, and news reading. Higher levels use more bandwidth.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(subtitle)

        let cardWidth = Styles.onboardingSize.width - Styles.windowPadding * 2

        for level in AppSettings.ActivityLevel.allCases {
            let card = makeActivityCard(level: level)
            stack.addArrangedSubview(card)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: cardWidth).isActive = true
        }

        return stack
    }

    private func makeActivityCard(level: AppSettings.ActivityLevel) -> NSView {
        let isSelected = level == activityLevel

        // Card background
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = Styles.cardCornerRadius
        card.layer?.borderWidth = isSelected ? 2 : 0.5
        card.layer?.borderColor = isSelected
            ? Styles.accentColor.cgColor
            : Styles.separator.withAlphaComponent(0.3).cgColor
        card.layer?.backgroundColor = Styles.cardBackground.cgColor

        // Click gesture
        let clickButton = NSButton()
        clickButton.translatesAutoresizingMaskIntoConstraints = false
        clickButton.isBordered = false
        clickButton.title = ""
        clickButton.target = self
        clickButton.action = #selector(activityCardClicked(_:))
        let tagMap: [AppSettings.ActivityLevel: Int] = [.low: 950, .medium: 951, .high: 952]
        clickButton.tag = tagMap[level] ?? 950
        card.addSubview(clickButton)

        // Name + sessions/hour on the same line
        let nameLabel = Styles.label(level.displayName, font: Styles.headlineFont)
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)

        let rateLabel = Styles.label(level.sessionsPerHour, font: Styles.captionFont, color: Styles.tertiaryLabel)

        let headerRow = NSStackView(views: [nameLabel, rateLabel])
        headerRow.orientation = .horizontal
        headerRow.spacing = 8

        // Description
        let descLabel = Styles.label(level.description, font: Styles.captionFont, color: Styles.secondaryLabel)
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Text column
        let textStack = NSStackView(views: [headerRow, descLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        // Checkmark
        let checkmark = NSImageView()
        let symbolName = isSelected ? "checkmark.circle.fill" : "circle"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: isSelected ? "Selected" : "Not selected") {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            checkmark.image = img.withSymbolConfiguration(config)
            checkmark.contentTintColor = isSelected ? Styles.accentColor : Styles.tertiaryLabel
        }
        checkmark.setContentHuggingPriority(.required, for: .horizontal)

        // Row layout
        let row = NSStackView(views: [textStack, checkmark])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        card.addSubview(row)

        NSLayoutConstraint.activate([
            clickButton.topAnchor.constraint(equalTo: card.topAnchor),
            clickButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            clickButton.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    @objc private func activityCardClicked(_ sender: NSButton) {
        let levels: [Int: AppSettings.ActivityLevel] = [950: .low, 951: .medium, 952: .high]
        guard let level = levels[sender.tag] else { return }
        activityLevel = level

        // Refresh the step to update checkmarks and border highlight
        showStep(2)
    }

    // MARK: - Step 4: Persona

    private func buildPersonaStep() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "person.text.rectangle", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .light)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = Styles.accentColor
        }
        stack.addArrangedSubview(iconView)

        let title = Styles.label("Your Roommate\u{2019}s Persona", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let body = Styles.label(
            "Digital Roommate uses a fake persona to generate realistic traffic. " +
            "The persona defines what your roommate searches for, shops for, watches, " +
            "and reads \u{2014} making the decoy activity look like a real person.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(body)

        let detail = Styles.label(
            "You can customize or randomize the persona anytime in Settings \u{2192} Persona. " +
            "You can also create multiple personas and rotate between them.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(detail)

        let personaName = Persona.loadDefault().name
        let highlight = Styles.label(
            "Current persona: \(personaName)",
            font: Styles.headlineFont
        )
        stack.addArrangedSubview(highlight)

        return stack
    }

    // MARK: - Step 5: Ready

    private func buildReadyStep() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .light)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = NSColor.systemGreen
        }
        stack.addArrangedSubview(iconView)

        let title = Styles.label("You're All Set", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        // Summary
        let enabledModules = moduleToggles.filter { $0.value }.map { $0.key }
        let moduleNames = enabledModules.sorted().map { id -> String in
            switch id {
            case "search": return "Search Noise"
            case "shopping": return "Shopping Noise"
            case "video": return "Video Noise"
            case "news": return "News & Browsing"
            default: return id
            }
        }

        let personaName = Persona.loadDefault().name
        let summaryText = """
        Modules: \(moduleNames.isEmpty ? "None" : moduleNames.joined(separator: ", "))
        Activity level: \(activityLevel.displayName)
        Persona: \(personaName)
        """

        let summary = Styles.label(summaryText, font: Styles.bodyFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(summary)

        let detail = Styles.label(
            "Digital Roommate will start generating traffic in the background. " +
            "You can adjust settings anytime from the menu bar icon.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(detail)

        return stack
    }

    // MARK: - Finish

    private func finishOnboarding() {
        // Apply settings from onboarding choices
        SettingsManager.shared.update { settings in
            settings.activityLevel = activityLevel
            settings.searchEnabled = moduleToggles["search"] ?? true
            settings.shoppingEnabled = moduleToggles["shopping"] ?? true
            settings.videoEnabled = moduleToggles["video"] ?? true
            settings.newsEnabled = moduleToggles["news"] ?? true
        }

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Close window and notify delegate
        window?.close()
        onComplete?()
    }
}
