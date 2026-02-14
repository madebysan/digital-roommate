import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

// Sidebar-based settings window with card-grouped controls.
// Replaces the old NSTabView layout with a modern macOS look:
// sidebar navigation on the left, scrollable content on the right.
// Most changes apply immediately through SettingsManager. Persona section has
// a Save button since it writes to the active persona file.
class SettingsWindowController: NSWindowController, NSTextViewDelegate {

    static let shared = SettingsWindowController()

    // Sidebar
    private var sidebarTableView: NSTableView!
    private var contentScrollView: NSScrollView!
    private var contentDocumentView: NSView!

    // Section names and icons
    private let sections: [(name: String, icon: String)] = [
        ("General", "gearshape"),
        ("Search", "magnifyingglass"),
        ("Shopping", "cart"),
        ("Video", "play.rectangle"),
        ("News", "newspaper"),
        ("Sites & Privacy", "globe.badge.chevron.backward"),
        ("Persona", "person.text.rectangle"),
    ]
    private var selectedSection = 0

    // References for text views that auto-save on blur
    private weak var visitedSitesTextView: NSTextView?
    private weak var blockedDomainsTextView: NSTextView?
    private weak var personaPickerButton: NSPopUpButton?

    // Persona field references (strong — cleared on section rebuild)
    private struct PersonaFieldRefs {
        let interests: NSTextView
        var searchTopics: [(category: NSTextField, items: NSTextView, originalTemplates: [String])]
        var shopping: [(name: NSTextField, terms: NSTextView, originalProductUrls: [String])]
        var video: [(topic: NSTextField, queries: NSTextView, originalChannelUrls: [String], originalVideoUrls: [String])]
    }
    private var personaFieldRefs: PersonaFieldRefs?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Styles.settingsSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupLayout()
        selectSection(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func show() {
        selectSection(selectedSection)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout: Sidebar + Content

    private func setupLayout() {
        guard let contentView = window?.contentView else { return }

        // --- Sidebar ---
        let sidebarScroll = NSScrollView()
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebarScroll.hasVerticalScroller = false
        sidebarScroll.drawsBackground = false
        sidebarScroll.borderType = .noBorder

        sidebarTableView = NSTableView()
        sidebarTableView.headerView = nil
        sidebarTableView.rowHeight = 32
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.style = .sourceList

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        column.width = Styles.sidebarWidth - 20
        sidebarTableView.addTableColumn(column)

        sidebarTableView.delegate = self
        sidebarTableView.dataSource = self

        sidebarScroll.documentView = sidebarTableView

        // Sidebar background (visual effect for sidebar material)
        let sidebarContainer = NSVisualEffectView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.material = .sidebar
        sidebarContainer.blendingMode = .behindWindow
        sidebarContainer.addSubview(sidebarScroll)

        NSLayoutConstraint.activate([
            sidebarScroll.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 8),
            sidebarScroll.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScroll.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScroll.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])

        contentView.addSubview(sidebarContainer)

        // --- Divider ---
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(divider)

        // --- Content Area ---
        contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.drawsBackground = false
        contentScrollView.borderType = .noBorder
        contentScrollView.automaticallyAdjustsContentInsets = false
        contentScrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        contentDocumentView = NSView()
        contentDocumentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = contentDocumentView

        contentView.addSubview(contentScrollView)

        // --- Constraints ---
        NSLayoutConstraint.activate([
            sidebarContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: Styles.sidebarWidth),

            divider.topAnchor.constraint(equalTo: contentView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            contentScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentDocumentView.topAnchor.constraint(equalTo: contentScrollView.contentView.topAnchor),
            contentDocumentView.leadingAnchor.constraint(equalTo: contentScrollView.contentView.leadingAnchor),
            contentDocumentView.widthAnchor.constraint(equalTo: contentScrollView.contentView.widthAnchor),
        ])
    }

    // MARK: - Section Selection

    private func selectSection(_ index: Int) {
        selectedSection = index
        sidebarTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)

        // Clear persona refs when switching away from persona section
        if index != 6 {
            personaFieldRefs = nil
        }

        // Build the content for the selected section
        let contentStack: NSView
        switch index {
        case 0: contentStack = buildGeneralSection()
        case 1: contentStack = buildSearchSection()
        case 2: contentStack = buildShoppingSection()
        case 3: contentStack = buildVideoSection()
        case 4: contentStack = buildNewsSection()
        case 5: contentStack = buildSitesSection()
        case 6: contentStack = buildPersonaSection()
        default: return
        }

        // Replace document view content
        contentDocumentView.subviews.forEach { $0.removeFromSuperview() }
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentDocumentView.addSubview(contentStack)

        let contentWidth = Styles.settingsSize.width - Styles.sidebarWidth - 1
        let padding = Styles.windowPadding

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentDocumentView.topAnchor, constant: padding),
            contentStack.leadingAnchor.constraint(equalTo: contentDocumentView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: contentDocumentView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: contentDocumentView.bottomAnchor, constant: -padding),
            contentStack.widthAnchor.constraint(equalToConstant: contentWidth - padding * 2),
        ])

        // Scroll to top
        contentScrollView.documentView?.scroll(.zero)
    }

    // MARK: - General Section

    private func buildGeneralSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        // Section title
        let title = Styles.label("General", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        // --- Activity Level ---
        let activityLabel = Styles.sectionHeader("Activity Level")
        let activitySegment = NSSegmentedControl(labels: ["Low", "Medium", "High"], trackingMode: .selectOne, target: self, action: #selector(activityLevelChanged(_:)))
        activitySegment.selectedSegment = AppSettings.ActivityLevel.allCases.firstIndex(of: settings.activityLevel) ?? 1
        activitySegment.segmentDistribution = .fillEqually
        activitySegment.tag = 100

        let activityStack = NSStackView(views: [activityLabel, activitySegment])
        activityStack.orientation = .vertical
        activityStack.alignment = .leading
        activityStack.spacing = Styles.itemSpacing
        stack.addArrangedSubview(activityStack)

        // --- Active Time Blocks (card with toggle rows) ---
        let timeLabel = Styles.sectionHeader("Active Time Blocks")
        stack.addArrangedSubview(timeLabel)

        let timeBlocks: [(String, String, Bool, Int)] = [
            ("Morning", "6 AM \u{2013} 12 PM", settings.morningEnabled, 200),
            ("Afternoon", "12 \u{2013} 6 PM", settings.afternoonEnabled, 201),
            ("Evening", "6 \u{2013} 11 PM", settings.eveningEnabled, 202),
            ("Late Night", "11 PM \u{2013} 1 AM", settings.lateNightEnabled, 203),
            ("Vampire", "1 \u{2013} 5 AM", settings.vampireEnabled, 204),
            ("Early Morning", "5 \u{2013} 6 AM", settings.earlyMorningEnabled, 205),
        ]

        var timeRows: [NSView] = []
        for (i, block) in timeBlocks.enumerated() {
            let (row, toggle) = Styles.toggleRow(
                title: block.0, subtitle: block.1,
                isOn: block.2, target: self, action: #selector(toggleChanged(_:))
            )
            toggle.tag = block.3
            timeRows.append(row)
            if i < timeBlocks.count - 1 {
                timeRows.append(Styles.cardDivider())
            }
        }
        let timeCard = Styles.settingsCard(timeRows)
        stack.addArrangedSubview(timeCard)

        // --- Max Browsers + Launch at Login (card) ---
        let (browserRow, browserPopup) = Styles.popupRow(
            title: "Max Concurrent Browsers",
            items: ["1", "2", "3"],
            selectedIndex: settings.maxConcurrentBrowsers - 1,
            target: self, action: #selector(popupChanged(_:))
        )
        browserPopup.tag = 300

        let (loginRow, loginToggle) = Styles.toggleRow(
            title: "Launch at Login", isOn: settings.launchAtLogin,
            target: self, action: #selector(toggleChanged(_:))
        )
        loginToggle.tag = 400

        let miscCard = Styles.settingsCard([browserRow, Styles.cardDivider(), loginRow])
        stack.addArrangedSubview(miscCard)

        return stack
    }

    // MARK: - Search Section

    private func buildSearchSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        let title = Styles.label("Search", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        // --- Search Engines (card) ---
        let enginesLabel = Styles.sectionHeader("Search Engines")
        stack.addArrangedSubview(enginesLabel)

        let engines: [(String, Bool, Int)] = [
            ("Google", settings.searchGoogle, 500),
            ("Bing", settings.searchBing, 501),
            ("DuckDuckGo", settings.searchDuckDuckGo, 502),
        ]

        var engineRows: [NSView] = []
        for (i, eng) in engines.enumerated() {
            let (row, toggle) = Styles.toggleRow(
                title: eng.0, isOn: eng.1,
                target: self, action: #selector(toggleChanged(_:))
            )
            toggle.tag = eng.2
            engineRows.append(row)
            if i < engines.count - 1 {
                engineRows.append(Styles.cardDivider())
            }
        }
        let engineCard = Styles.settingsCard(engineRows)
        stack.addArrangedSubview(engineCard)

        // --- Behavior (card) ---
        let behaviorLabel = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorLabel)

        let (burstRow, burstToggle) = Styles.toggleRow(
            title: "Burst mode", subtitle: "Related query clusters",
            isOn: settings.searchBurstMode,
            target: self, action: #selector(toggleChanged(_:))
        )
        burstToggle.tag = 503

        let (clickRow, clickToggle) = Styles.toggleRow(
            title: "Click through to results", isOn: settings.searchClickThrough,
            target: self, action: #selector(toggleChanged(_:))
        )
        clickToggle.tag = 504

        let behaviorCard = Styles.settingsCard([burstRow, Styles.cardDivider(), clickRow])
        stack.addArrangedSubview(behaviorCard)

        return stack
    }

    // MARK: - Shopping Section

    private func buildShoppingSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        let title = Styles.label("Shopping", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let siteNote = Styles.label(
            "Browses Amazon.com \u{2014} searches for products, views pages, scrolls images and reviews.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(siteNote)

        // --- Products per session + behavior (card) ---
        let (productsRow, productsPopup) = Styles.popupRow(
            title: "Products per session",
            items: ["1", "2", "3", "4"],
            selectedIndex: settings.shoppingProductsPerSession - 1,
            target: self, action: #selector(popupChanged(_:))
        )
        productsPopup.tag = 600

        let (imagesRow, imagesToggle) = Styles.toggleRow(
            title: "Browse product images", isOn: settings.shoppingBrowseImages,
            target: self, action: #selector(toggleChanged(_:))
        )
        imagesToggle.tag = 610

        let (reviewsRow, reviewsToggle) = Styles.toggleRow(
            title: "Scroll to reviews", isOn: settings.shoppingScrollToReviews,
            target: self, action: #selector(toggleChanged(_:))
        )
        reviewsToggle.tag = 611

        let card = Styles.settingsCard([
            productsRow, Styles.cardDivider(),
            imagesRow, Styles.cardDivider(),
            reviewsRow,
        ])
        stack.addArrangedSubview(card)

        return stack
    }

    // MARK: - Video Section

    private func buildVideoSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        let title = Styles.label("Video", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let siteNote = Styles.label(
            "Watches YouTube.com videos \u{2014} muted, with realistic watch durations and ad skipping.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(siteNote)

        // --- Max watch duration ---
        let durationLabel = Styles.sectionHeader("Max Watch Duration")
        let durationSegment = NSSegmentedControl(labels: ["2 min", "5 min", "10 min", "15 min"], trackingMode: .selectOne, target: self, action: #selector(videoDurationChanged(_:)))
        let durationValues = [2, 5, 10, 15]
        durationSegment.selectedSegment = durationValues.firstIndex(of: settings.videoMaxWatchMinutes) ?? 2
        durationSegment.segmentDistribution = .fillEqually
        durationSegment.tag = 700

        let durationStack = NSStackView(views: [durationLabel, durationSegment])
        durationStack.orientation = .vertical
        durationStack.alignment = .leading
        durationStack.spacing = Styles.itemSpacing
        stack.addArrangedSubview(durationStack)

        // --- Behavior (card) ---
        let behaviorLabel = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorLabel)

        let (skipRow, skipToggle) = Styles.toggleRow(
            title: "Auto-skip ads", isOn: settings.videoAutoSkipAds,
            target: self, action: #selector(toggleChanged(_:))
        )
        skipToggle.tag = 710

        let (muteRow, muteToggle) = Styles.toggleRow(
            title: "Mute videos", isOn: settings.videoMute,
            target: self, action: #selector(toggleChanged(_:))
        )
        muteToggle.tag = 711

        let behaviorCard = Styles.settingsCard([skipRow, Styles.cardDivider(), muteRow])
        stack.addArrangedSubview(behaviorCard)

        return stack
    }

    // MARK: - News Section

    private func buildNewsSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        let title = Styles.label("News", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        let siteNote = Styles.label(
            "Reads articles from news sites defined in your persona. See Sites & Privacy to view or change them.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(siteNote)

        // --- All news settings in one card ---
        let (articlesRow, articlesPopup) = Styles.popupRow(
            title: "Articles per session",
            items: ["1", "2", "3", "4", "5"],
            selectedIndex: settings.newsArticlesPerSession - 1,
            target: self, action: #selector(popupChanged(_:))
        )
        articlesPopup.tag = 800

        let (sitesRow, sitesPopup) = Styles.popupRow(
            title: "Sites per session",
            items: ["1", "2", "3"],
            selectedIndex: settings.newsSitesPerSession - 1,
            target: self, action: #selector(popupChanged(_:))
        )
        sitesPopup.tag = 810

        let (followRow, followToggle) = Styles.toggleRow(
            title: "Follow related links", isOn: settings.newsFollowRelatedLinks,
            target: self, action: #selector(toggleChanged(_:))
        )
        followToggle.tag = 820

        let card = Styles.settingsCard([
            articlesRow, Styles.cardDivider(),
            sitesRow, Styles.cardDivider(),
            followRow,
        ])
        stack.addArrangedSubview(card)

        return stack
    }

    // MARK: - Sites & Privacy Section

    private func buildSitesSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let settings = SettingsManager.shared.current

        let title = Styles.label("Sites & Privacy", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        // --- Visited Sites ---
        let sitesHeader = Styles.sectionHeader("Sites Your Roommate Visits")
        let sitesDesc = Styles.label(
            "One URL per line. Add sites to browse, or remove ones you don\u{2019}t want visited.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(sitesHeader)
        stack.addArrangedSubview(sitesDesc)

        let (sitesScroll, sitesTV) = makeEditableTextArea(
            content: settings.effectiveVisitedSites.joined(separator: "\n"), height: 120
        )
        sitesTV.delegate = self
        visitedSitesTextView = sitesTV
        stack.addArrangedSubview(sitesScroll)

        let sitesNote = Styles.label(
            "Search results and in-article links may also lead to other sites.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        stack.addArrangedSubview(sitesNote)

        // --- Blocked Domains ---
        let blockedHeader = Styles.sectionHeader("Blocked Domains")
        let blockedDesc = Styles.label(
            "Domains your roommate will never visit. One per line.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        stack.addArrangedSubview(blockedHeader)
        stack.addArrangedSubview(blockedDesc)

        let (blockedScroll, blockedTV) = makeEditableTextArea(
            content: settings.blockedDomains.joined(separator: "\n"), height: 72
        )
        blockedTV.delegate = self
        blockedDomainsTextView = blockedTV
        stack.addArrangedSubview(blockedScroll)

        let blockedExample = Styles.label(
            "Example: facebook.com, reddit.com",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        stack.addArrangedSubview(blockedExample)

        return stack
    }

    // MARK: - Persona Section

    private func buildPersonaSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing

        let persona = Persona.loadDefault()

        let title = Styles.label("Persona", font: Styles.titleFont)
        stack.addArrangedSubview(title)

        // --- Persona Picker ---
        Persona.ensureDefaultExists()
        let pickerLabel = Styles.sectionHeader("Active Persona")
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.target = self
        picker.action = #selector(personaPickerChanged(_:))
        let allPersonas = Persona.listAll()
        let activeName = SettingsManager.shared.current.activePersonaName
        for pName in allPersonas {
            picker.addItem(withTitle: pName)
        }
        if let idx = allPersonas.firstIndex(of: activeName) {
            picker.selectItem(at: idx)
        }
        personaPickerButton = picker

        let pickerRow = NSStackView(views: [pickerLabel, picker])
        pickerRow.orientation = .horizontal
        pickerRow.spacing = 12
        pickerRow.alignment = .centerY
        stack.addArrangedSubview(pickerRow)

        // --- Action Buttons ---
        let randomizeBtn = NSButton(title: "Randomize", target: self, action: #selector(randomizePersona(_:)))
        randomizeBtn.bezelStyle = .rounded
        let exportBtn = NSButton(title: "Export\u{2026}", target: self, action: #selector(exportPersona(_:)))
        exportBtn.bezelStyle = .rounded
        let resetBtn = NSButton(title: "Reset", target: self, action: #selector(resetPersona(_:)))
        resetBtn.bezelStyle = .rounded

        let actionRow = NSStackView(views: [randomizeBtn, exportBtn, resetBtn])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        stack.addArrangedSubview(actionRow)

        // --- Interests ---
        let interestsHeader = Styles.sectionHeader("Interests")
        let interestsDesc = Styles.label("One per line. Shapes search and browsing behavior.", font: Styles.captionFont, color: Styles.secondaryLabel)
        let (interestsScroll, interestsTV) = makeEditableTextArea(
            content: persona.interests.joined(separator: "\n"), height: 70
        )
        stack.addArrangedSubview(interestsHeader)
        stack.addArrangedSubview(interestsDesc)
        stack.addArrangedSubview(interestsScroll)

        // --- Search Topics ---
        let searchHeader = Styles.sectionHeader("Search Topics")
        let searchDesc = Styles.label("What your roommate searches for. Each topic has a category and a list of search items.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(searchHeader)
        stack.addArrangedSubview(searchDesc)

        var searchRefs: [(category: NSTextField, items: NSTextView, originalTemplates: [String])] = []
        for (i, topic) in persona.searchTopics.enumerated() {
            let catLabel = Styles.label("Category:", font: Styles.smallBoldFont)
            let catField = NSTextField(string: topic.category)
            catField.font = Styles.bodyFont
            catField.placeholderString = "e.g. cooking"
            NSLayoutConstraint.activate([catField.widthAnchor.constraint(equalToConstant: 200)])
            let catRow = NSStackView(views: [catLabel, catField])
            catRow.orientation = .horizontal
            catRow.spacing = 8

            let itemsLabel = Styles.label("Items:", font: Styles.captionFont, color: Styles.secondaryLabel)
            let (itemsScroll, itemsTV) = makeEditableTextArea(
                content: topic.items.joined(separator: "\n"), height: 70
            )

            let topicGroup = NSStackView(views: [catRow, itemsLabel, itemsScroll])
            topicGroup.orientation = .vertical
            topicGroup.alignment = .leading
            topicGroup.spacing = 4
            stack.addArrangedSubview(topicGroup)

            searchRefs.append((category: catField, items: itemsTV, originalTemplates: topic.templates))

            if i < persona.searchTopics.count - 1 {
                let gap = NSView()
                gap.translatesAutoresizingMaskIntoConstraints = false
                gap.heightAnchor.constraint(equalToConstant: 4).isActive = true
                stack.addArrangedSubview(gap)
            }
        }

        // --- Shopping ---
        let shoppingHeader = Styles.sectionHeader("Shopping")
        let shoppingDesc = Styles.label("Products your roommate browses on Amazon.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(shoppingHeader)
        stack.addArrangedSubview(shoppingDesc)

        var shoppingRefs: [(name: NSTextField, terms: NSTextView, originalProductUrls: [String])] = []
        for cat in persona.shoppingCategories {
            let nameLabel = Styles.label("Category:", font: Styles.smallBoldFont)
            let nameField = NSTextField(string: cat.name)
            nameField.font = Styles.bodyFont
            nameField.placeholderString = "e.g. Kitchen"
            NSLayoutConstraint.activate([nameField.widthAnchor.constraint(equalToConstant: 200)])
            let nameRow = NSStackView(views: [nameLabel, nameField])
            nameRow.orientation = .horizontal
            nameRow.spacing = 8

            let termsLabel = Styles.label("Search terms:", font: Styles.captionFont, color: Styles.secondaryLabel)
            let (termsScroll, termsTV) = makeEditableTextArea(
                content: cat.searchTerms.joined(separator: "\n"), height: 70
            )

            let catGroup = NSStackView(views: [nameRow, termsLabel, termsScroll])
            catGroup.orientation = .vertical
            catGroup.alignment = .leading
            catGroup.spacing = 4
            stack.addArrangedSubview(catGroup)

            shoppingRefs.append((name: nameField, terms: termsTV, originalProductUrls: cat.productUrls))
        }

        // --- Video ---
        let videoHeader = Styles.sectionHeader("Video")
        let videoDesc = Styles.label("What your roommate watches on YouTube.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(videoHeader)
        stack.addArrangedSubview(videoDesc)

        var videoRefs: [(topic: NSTextField, queries: NSTextView, originalChannelUrls: [String], originalVideoUrls: [String])] = []
        for interest in persona.videoInterests {
            let topicLabel = Styles.label("Topic:", font: Styles.smallBoldFont)
            let topicField = NSTextField(string: interest.topic)
            topicField.font = Styles.bodyFont
            topicField.placeholderString = "e.g. cooking"
            NSLayoutConstraint.activate([topicField.widthAnchor.constraint(equalToConstant: 200)])
            let topicRow = NSStackView(views: [topicLabel, topicField])
            topicRow.orientation = .horizontal
            topicRow.spacing = 8

            let queriesLabel = Styles.label("Search queries:", font: Styles.captionFont, color: Styles.secondaryLabel)
            let (queriesScroll, queriesTV) = makeEditableTextArea(
                content: interest.searchQueries.joined(separator: "\n"), height: 70
            )

            let interestGroup = NSStackView(views: [topicRow, queriesLabel, queriesScroll])
            interestGroup.orientation = .vertical
            interestGroup.alignment = .leading
            interestGroup.spacing = 4
            stack.addArrangedSubview(interestGroup)

            videoRefs.append((
                topic: topicField, queries: queriesTV,
                originalChannelUrls: interest.channelUrls, originalVideoUrls: interest.videoUrls
            ))
        }

        // --- Save ---
        let saveButton = NSButton(title: "Save Changes", target: self, action: #selector(savePersona(_:)))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let openButton = NSButton(title: "Open Persona File\u{2026}", target: self, action: #selector(openPersonaFile(_:)))
        openButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [saveButton, openButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        stack.addArrangedSubview(buttonRow)

        let saveNote = Styles.label("Changes take effect on the next browsing session.", font: Styles.captionFont, color: Styles.tertiaryLabel)
        stack.addArrangedSubview(saveNote)

        // Store field references for saving
        personaFieldRefs = PersonaFieldRefs(
            interests: interestsTV,
            searchTopics: searchRefs,
            shopping: shoppingRefs,
            video: videoRefs
        )

        return stack
    }

    // MARK: - Helpers

    /// Creates a scrollable editable text area (reusable across sections)
    private func makeEditableTextArea(content: String, height: CGFloat) -> (NSScrollView, NSTextView) {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.string = content
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        let contentWidth = Styles.settingsSize.width - Styles.sidebarWidth - 1 - Styles.windowPadding * 2
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height),
            scrollView.widthAnchor.constraint(equalToConstant: contentWidth),
        ])

        return (scrollView, textView)
    }

    /// Splits a text view's content into trimmed, non-empty lines
    private func parseLines(_ textView: NSTextView) -> [String] {
        return textView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Unified Toggle Handler

    @objc private func toggleChanged(_ sender: NSSwitch) {
        let on = sender.state == .on
        SettingsManager.shared.update { settings in
            switch sender.tag {
            // General — time blocks
            case 200: settings.morningEnabled = on
            case 201: settings.afternoonEnabled = on
            case 202: settings.eveningEnabled = on
            case 203: settings.lateNightEnabled = on
            case 204: settings.vampireEnabled = on
            case 205: settings.earlyMorningEnabled = on
            // General — launch at login
            case 400: settings.launchAtLogin = on
            // Search — engines
            case 500: settings.searchGoogle = on
            case 501: settings.searchBing = on
            case 502: settings.searchDuckDuckGo = on
            // Search — behavior
            case 503: settings.searchBurstMode = on
            case 504: settings.searchClickThrough = on
            // Shopping — behavior
            case 610: settings.shoppingBrowseImages = on
            case 611: settings.shoppingScrollToReviews = on
            // Video — behavior
            case 710: settings.videoAutoSkipAds = on
            case 711: settings.videoMute = on
            // News — behavior
            case 820: settings.newsFollowRelatedLinks = on
            default: break
            }
        }
        // Sync launch-at-login with system if that toggle was changed
        if sender.tag == 400 {
            SettingsManager.shared.syncLaunchAtLogin()
        }
    }

    // MARK: - Unified Popup Handler

    @objc private func popupChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        SettingsManager.shared.update { settings in
            switch sender.tag {
            case 300: settings.maxConcurrentBrowsers = index + 1
            case 600: settings.shoppingProductsPerSession = index + 1
            case 800: settings.newsArticlesPerSession = index + 1
            case 810: settings.newsSitesPerSession = index + 1
            default: break
            }
        }
    }

    // MARK: - Segmented Control Actions

    @objc private func activityLevelChanged(_ sender: NSSegmentedControl) {
        let levels = AppSettings.ActivityLevel.allCases
        guard sender.selectedSegment < levels.count else { return }
        SettingsManager.shared.update { $0.activityLevel = levels[sender.selectedSegment] }
    }

    @objc private func videoDurationChanged(_ sender: NSSegmentedControl) {
        let values = [2, 5, 10, 15]
        guard sender.selectedSegment < values.count else { return }
        SettingsManager.shared.update { $0.videoMaxWatchMinutes = values[sender.selectedSegment] }
    }

    // MARK: - Sites & Privacy — Auto-save on blur

    func textDidEndEditing(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let lines = textView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if textView === visitedSitesTextView {
            SettingsManager.shared.update { $0.visitedSites = lines }
        } else if textView === blockedDomainsTextView {
            SettingsManager.shared.update { $0.blockedDomains = lines }
        }
    }

    // MARK: - Persona Actions

    @objc private func personaPickerChanged(_ sender: NSPopUpButton) {
        guard let selectedName = sender.titleOfSelectedItem else { return }
        SettingsManager.shared.update {
            $0.activePersonaName = selectedName
            $0.visitedSites = []
        }
        selectSection(6)
    }

    @objc private func randomizePersona(_ sender: NSButton) {
        let newPersona = PersonaGenerator.randomPersona()
        Persona.save(newPersona, named: newPersona.name)
        SettingsManager.shared.update {
            $0.activePersonaName = newPersona.name
            $0.visitedSites = []
        }
        selectSection(6)
    }

    @objc private func exportPersona(_ sender: NSButton) {
        let activeName = SettingsManager.shared.current.activePersonaName
        guard let persona = Persona.load(named: activeName) else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(activeName).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        savePanel.beginSheetModal(for: window!) { response in
            guard response == .OK, let url = savePanel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(persona) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    @objc private func resetPersona(_ sender: NSButton) {
        guard let refs = personaFieldRefs else { return }
        refs.interests.string = ""
        for ref in refs.searchTopics {
            ref.category.stringValue = ""
            ref.items.string = ""
        }
        for ref in refs.shopping {
            ref.name.stringValue = ""
            ref.terms.string = ""
        }
        for ref in refs.video {
            ref.topic.stringValue = ""
            ref.queries.string = ""
        }
    }

    @objc private func savePersona(_ sender: NSButton) {
        guard let refs = personaFieldRefs else { return }
        let original = Persona.loadDefault()
        let activeName = SettingsManager.shared.current.activePersonaName
        let interests = parseLines(refs.interests)

        // Rebuild search topics (preserve templates from original)
        var searchTopics: [Persona.SearchTopic] = []
        for (i, ref) in refs.searchTopics.enumerated() {
            let cat = ref.category.stringValue.trimmingCharacters(in: .whitespaces)
            guard !cat.isEmpty else { continue }
            let items = parseLines(ref.items)
            let templates = ref.originalTemplates.isEmpty
                ? (i < original.searchTopics.count ? original.searchTopics[i].templates : ["best {item}", "how to {item}"])
                : ref.originalTemplates
            searchTopics.append(Persona.SearchTopic(category: cat, templates: templates, items: items))
        }

        // Rebuild shopping categories (preserve productUrls from original)
        var shoppingCategories: [Persona.ShoppingCategory] = []
        for ref in refs.shopping {
            let catName = ref.name.stringValue.trimmingCharacters(in: .whitespaces)
            guard !catName.isEmpty else { continue }
            let terms = parseLines(ref.terms)
            shoppingCategories.append(Persona.ShoppingCategory(name: catName, searchTerms: terms, productUrls: ref.originalProductUrls))
        }

        // Rebuild video interests (preserve channel/video URLs from original)
        var videoInterests: [Persona.VideoInterest] = []
        for ref in refs.video {
            let topic = ref.topic.stringValue.trimmingCharacters(in: .whitespaces)
            guard !topic.isEmpty else { continue }
            let queries = parseLines(ref.queries)
            videoInterests.append(Persona.VideoInterest(
                topic: topic, channelUrls: ref.originalChannelUrls,
                videoUrls: ref.originalVideoUrls, searchQueries: queries
            ))
        }

        let newPersona = Persona(
            name: original.name,
            age: original.age,
            profession: original.profession,
            interests: interests.isEmpty ? original.interests : interests,
            searchTopics: searchTopics.isEmpty ? original.searchTopics : searchTopics,
            shoppingCategories: shoppingCategories.isEmpty ? original.shoppingCategories : shoppingCategories,
            videoInterests: videoInterests.isEmpty ? original.videoInterests : videoInterests,
            newsSites: original.newsSites,
            activeHours: original.activeHours
        )

        Persona.save(newPersona, named: activeName)

        // Visual feedback
        sender.title = "Saved!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sender.title = "Save Changes"
        }
    }

    @objc private func openPersonaFile(_ sender: NSButton) {
        let path = Persona.activePersonaFilePath
        Persona.ensureDefaultExists()
        NSWorkspace.shared.open(path)
    }
}

// MARK: - NSTableViewDataSource & Delegate (Sidebar)

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellID = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = Styles.bodyFont
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        let section = sections[row]
        cell.textField?.stringValue = section.name
        if let img = NSImage(systemSymbolName: section.icon, accessibilityDescription: section.name) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            cell.imageView?.image = img.withSymbolConfiguration(config)
            cell.imageView?.contentTintColor = .secondaryLabelColor
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0 else { return }
        selectSection(row)
    }
}
