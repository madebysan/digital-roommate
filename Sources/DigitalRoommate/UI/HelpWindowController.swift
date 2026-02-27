import Cocoa

// "About Digital Roommate" window.
// Native AppKit layout showing what the app does, how each module works,
// and how to customize the persona. Uses shared Styles helpers for
// consistency with Settings and Onboarding windows.
// Singleton — calling show() again brings the existing window to front.
class HelpWindowController: NSWindowController {

    static let shared = HelpWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Styles.helpSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Digital Roommate"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Setup

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        // Scroll view wrapping the full content
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        // Main content stack
        let stack = buildContentStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        let padding = Styles.windowPadding
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -padding),
        ])
    }

    // MARK: - Content

    private func buildContentStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let cardWidth = Styles.helpSize.width - Styles.windowPadding * 2

        // --- Header (tight group: icon / title / subtitle / version) ---
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "person.fill.viewfinder", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: Styles.heroIconSize, weight: .light)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = Styles.accentColor
        }

        let title = Styles.label("Digital Roommate", font: Styles.titleFont)
        let subtitle = Styles.label("Privacy noise generator for macOS", font: Styles.bodyFont, color: Styles.secondaryLabel)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = Styles.label("Version \(version) (\(build))", font: Styles.captionFont, color: Styles.tertiaryLabel)

        let headerGroup = NSStackView(views: [iconView, title, subtitle, versionLabel])
        headerGroup.orientation = .vertical
        headerGroup.alignment = .leading
        headerGroup.spacing = Styles.headerGroupSpacing
        // A bit more space below the icon before the text
        headerGroup.setCustomSpacing(Styles.itemSpacing, after: iconView)
        stack.addArrangedSubview(headerGroup)

        let intro = Styles.label(
            "Digital Roommate creates realistic web traffic from a fake persona, making it look like " +
            "another person lives in your house. This poisons ISP-level and data-broker profiling by " +
            "mixing your real browsing with convincing decoy activity.",
            font: Styles.bodyFont
        )
        stack.addArrangedSubview(intro)

        // --- Divider ---
        stack.addArrangedSubview(makeDivider(width: cardWidth))

        // --- How It Works ---
        let howHeader = Styles.label("How It Works", font: Styles.headlineFont)
        stack.addArrangedSubview(howHeader)

        let howBody = Styles.label(
            "The app runs hidden browser sessions in the background using time-aware scheduling. " +
            "Activity levels vary throughout the day just like a real person \u{2014} more active in the " +
            "afternoon, quieter late at night.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(howBody)

        // --- Divider ---
        stack.addArrangedSubview(makeDivider(width: cardWidth))

        // --- Modules ---
        let modulesHeader = Styles.label("Modules", font: Styles.headlineFont)
        stack.addArrangedSubview(modulesHeader)

        let modules: [(String, String, String)] = [
            ("magnifyingglass", "Search Noise",
             "Runs searches on Google, Bing, and DuckDuckGo using your persona\u{2019}s interests. " +
             "Sometimes does multi-query research bursts. Clicks through to results to create realistic browsing trails."),
            ("cart", "Shopping Noise",
             "Browses Amazon \u{2014} searches for products, views product pages, scrolls through images and reviews. " +
             "Creates the impression of an active online shopper."),
            ("play.rectangle", "Video Noise",
             "Watches YouTube videos from your persona\u{2019}s interests. Plays muted, watches variable durations " +
             "(30\u{2013}90% of each video), and skips ads automatically."),
            ("newspaper", "News & Browsing",
             "Visits news sites, reads articles at realistic speed, and occasionally follows related links. " +
             "Covers general, tech, hobby, and professional sites."),
        ]

        for (icon, name, desc) in modules {
            let card = Styles.moduleInfoCard(icon: icon, title: name, description: desc, width: cardWidth)
            stack.addArrangedSubview(card)
        }

        // --- Divider ---
        stack.addArrangedSubview(makeDivider(width: cardWidth))

        // --- Customizing the Persona ---
        let personaHeader = Styles.label("Customizing the Persona", font: Styles.headlineFont)
        stack.addArrangedSubview(personaHeader)

        let personaIntro = Styles.label(
            "The fake persona (name, interests, shopping habits, video topics) defines what kind of person " +
            "your traffic looks like. To customize it:",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(personaIntro)

        let bullets = [
            "Open Settings \u{2192} Persona",
            "Edit the name, interests, search topics, shopping terms, and video queries",
            "Click Save Changes \u{2014} takes effect on the next browsing session",
        ]
        for bullet in bullets {
            let bulletLabel = Styles.label("\u{2022}  \(bullet)", font: Styles.bodyFont, color: Styles.secondaryLabel)
            stack.addArrangedSubview(bulletLabel)
        }

        let sitesNote = Styles.label(
            "Use Settings \u{2192} Sites & Privacy to see which sites the roommate visits and block specific domains.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(sitesNote)

        // --- Divider ---
        stack.addArrangedSubview(makeDivider(width: cardWidth))

        // --- Settings ---
        let settingsHeader = Styles.label("Settings", font: Styles.headlineFont)
        stack.addArrangedSubview(settingsHeader)

        let settingsBody = Styles.label(
            "Use Settings (in the menu bar dropdown) to control activity level, active time blocks, " +
            "and per-module options like which search engines to use, video watch duration, and more.",
            font: Styles.bodyFont,
            color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(settingsBody)

        // --- Divider ---
        stack.addArrangedSubview(makeDivider(width: cardWidth))

        // --- Footer ---
        let footer = Styles.label(
            "Digital Roommate \u{2014} Your data is your own.",
            font: Styles.captionFont,
            color: Styles.tertiaryLabel
        )
        stack.addArrangedSubview(footer)

        return stack
    }

    // MARK: - Helpers

    private func makeDivider(width: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1),
            container.widthAnchor.constraint(equalToConstant: width),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }
}
