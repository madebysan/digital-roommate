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
            let dot = NSBox()
            dot.boxType = .custom
            dot.cornerRadius = 4
            dot.fillColor = (i == 0 ? Styles.accentColor : Styles.tertiaryLabel)
            dot.borderWidth = 0
            dot.titlePosition = .noTitle
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            dotStack.addArrangedSubview(dot)
        }

        dotStack.setAccessibilityRole(.group)
        dotStack.setAccessibilityLabel("Step 1 of \(totalSteps)")
        bottomBar.addSubview(dotStack)

        // Navigation buttons
        backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .rounded
        bottomBar.addSubview(backButton)

        nextButton = Styles.accentButton("Continue", target: self, action: #selector(goNext))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(nextButton)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Styles.windowPadding),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Styles.windowPadding),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Styles.bottomBarPadding),
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

        // Cross-dissolve transition between steps
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            contentContainer.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }

            // Clear previous content
            self.contentContainer.subviews.forEach { $0.removeFromSuperview() }

            // Build step content
            let stepView: NSView
            switch step {
            case 0: stepView = self.buildWelcomeStep()
            case 1: stepView = self.buildModulesStep()
            case 2: stepView = self.buildActivityStep()
            case 3: stepView = self.buildPersonaStep()
            case 4: stepView = self.buildReadyStep()
            default: return
            }

            stepView.translatesAutoresizingMaskIntoConstraints = false
            self.contentContainer.addSubview(stepView)
            NSLayoutConstraint.activate([
                stepView.topAnchor.constraint(equalTo: self.contentContainer.topAnchor, constant: Styles.windowPadding),
                stepView.leadingAnchor.constraint(equalTo: self.contentContainer.leadingAnchor, constant: Styles.windowPadding),
                stepView.trailingAnchor.constraint(equalTo: self.contentContainer.trailingAnchor, constant: -Styles.windowPadding),
            ])

            // Fade in new content
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                self.contentContainer.animator().alphaValue = 1
            }
        }

        // Update dots
        for (i, dot) in dotStack.arrangedSubviews.enumerated() {
            (dot as? NSBox)?.fillColor = (i == step ? Styles.accentColor : Styles.tertiaryLabel)
        }
        dotStack.setAccessibilityLabel("Step \(step + 1) of \(totalSteps)")

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
            let config = NSImage.SymbolConfiguration(pointSize: Styles.heroIconSize, weight: .light)
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

        let cardWidth = Styles.onboardingSize.width - Styles.windowPadding * 2

        for (id, icon, name, desc) in modules {
            // Toggle for this module
            let toggle = NSSwitch()
            toggle.state = moduleToggles[id] == true ? .on : .off
            toggle.target = self
            toggle.action = #selector(moduleToggled(_:))
            toggle.controlSize = .small
            let tagMap = ["search": 0, "shopping": 1, "video": 2, "news": 3]
            toggle.tag = 900 + (tagMap[id] ?? 0)

            let card = Styles.moduleInfoCard(
                icon: icon, title: name, description: desc,
                trailingView: toggle, width: cardWidth
            )
            stack.addArrangedSubview(card)
        }

        return stack
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
        stack.spacing = Styles.sectionSpacing

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

        // Card background — NSBox handles dark mode color changes automatically
        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = Styles.cardCornerRadius
        card.borderWidth = isSelected ? 2 : 0.5
        card.borderColor = isSelected
            ? Styles.accentColor
            : Styles.separator.withAlphaComponent(0.3)
        card.fillColor = Styles.cardBackground
        card.titlePosition = .noTitle
        card.contentViewMargins = .zero

        guard let content = card.contentView else { return card }

        // Click gesture — accessible as a radio button for VoiceOver
        let clickButton = NSButton()
        clickButton.translatesAutoresizingMaskIntoConstraints = false
        clickButton.isBordered = false
        clickButton.title = ""
        clickButton.target = self
        clickButton.action = #selector(activityCardClicked(_:))
        let tagMap: [AppSettings.ActivityLevel: Int] = [.low: 950, .medium: 951, .high: 952]
        clickButton.tag = tagMap[level] ?? 950
        clickButton.setAccessibilityRole(.radioButton)
        clickButton.setAccessibilityLabel("\(level.displayName) — \(level.sessionsPerHour)")
        clickButton.setAccessibilityValue(isSelected ? "1" : "0")
        content.addSubview(clickButton)

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
            checkmark.contentTintColor = isSelected ? Styles.accentColor : Styles.secondaryLabel
        }
        checkmark.setContentHuggingPriority(.required, for: .horizontal)

        // Spacer pushes checkmark to right edge
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Row layout
        let row = NSStackView(views: [textStack, spacer, checkmark])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        content.addSubview(row)

        NSLayoutConstraint.activate([
            clickButton.topAnchor.constraint(equalTo: content.topAnchor),
            clickButton.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            clickButton.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            row.topAnchor.constraint(equalTo: content.topAnchor),
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor),
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
            let config = NSImage.SymbolConfiguration(pointSize: Styles.heroIconSize, weight: .light)
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
            let config = NSImage.SymbolConfiguration(pointSize: Styles.heroIconSize, weight: .light)
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
