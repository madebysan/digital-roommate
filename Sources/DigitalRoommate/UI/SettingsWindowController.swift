import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

// Tabbed settings window: General, Search, Shopping, Video, News, Sites & Privacy, Persona.
// Most changes apply immediately through SettingsManager. Persona tab has a Save button
// since it writes to the active persona file. Singleton — calling show() brings existing window to front.
class SettingsWindowController: NSWindowController, NSTabViewDelegate, NSTextViewDelegate {

    static let shared = SettingsWindowController()

    private var tabView: NSTabView!
    private weak var visitedSitesTextView: NSTextView?
    private weak var blockedDomainsTextView: NSTextView?
    private weak var personaPickerButton: NSPopUpButton?

    // Persona tab field references (strong — cleared on tab rebuild)
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
        setupTabs()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func show() {
        refreshAllTabs()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Tab Setup

    private func setupTabs() {
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder

        tabView.addTabViewItem(makeGeneralTab())
        tabView.addTabViewItem(makeSearchTab())
        tabView.addTabViewItem(makeShoppingTab())
        tabView.addTabViewItem(makeVideoTab())
        tabView.addTabViewItem(makeNewsTab())
        tabView.addTabViewItem(makeSitesTab())
        tabView.addTabViewItem(makePersonaTab())

        window?.contentView?.addSubview(tabView)

        if let contentView = window?.contentView {
            NSLayoutConstraint.activate([
                tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ])
        }
    }

    private func refreshAllTabs() {
        // Clear persona refs before rebuild (they'll be recreated by makePersonaTab)
        personaFieldRefs = nil

        // Rebuild tab contents to reflect current settings
        for (index, item) in tabView.tabViewItems.enumerated() {
            let newItem: NSTabViewItem
            switch index {
            case 0: newItem = makeGeneralTab()
            case 1: newItem = makeSearchTab()
            case 2: newItem = makeShoppingTab()
            case 3: newItem = makeVideoTab()
            case 4: newItem = makeNewsTab()
            case 5: newItem = makeSitesTab()
            case 6: newItem = makePersonaTab()
            default: continue
            }
            item.view = newItem.view
        }
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "General"
        item.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "General")

        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settings = SettingsManager.shared.current

        // Activity Level
        let activityLabel = Styles.sectionHeader("Activity Level")
        let activitySegment = NSSegmentedControl(labels: ["Low", "Medium", "High"], trackingMode: .selectOne, target: self, action: #selector(activityLevelChanged(_:)))
        activitySegment.selectedSegment = AppSettings.ActivityLevel.allCases.firstIndex(of: settings.activityLevel) ?? 1
        activitySegment.segmentDistribution = .fillEqually
        activitySegment.tag = 100

        let activityStack = NSStackView(views: [activityLabel, activitySegment])
        activityStack.orientation = .vertical
        activityStack.alignment = .leading
        activityStack.spacing = Styles.itemSpacing

        // Active Time Blocks
        let timeLabel = Styles.sectionHeader("Active Time Blocks")
        let timeBlocks: [(String, String, Bool)] = [
            ("Morning (6 AM\u{2013}12 PM)", "morning", settings.morningEnabled),
            ("Afternoon (12\u{2013}6 PM)", "afternoon", settings.afternoonEnabled),
            ("Evening (6\u{2013}11 PM)", "evening", settings.eveningEnabled),
            ("Late Night (11 PM\u{2013}1 AM)", "lateNight", settings.lateNightEnabled),
            ("Vampire (1\u{2013}5 AM)", "vampire", settings.vampireEnabled),
            ("Early Morning (5\u{2013}6 AM)", "earlyMorn", settings.earlyMorningEnabled),
        ]

        let timeStack = NSStackView()
        timeStack.orientation = .vertical
        timeStack.alignment = .leading
        timeStack.spacing = 4

        for (index, block) in timeBlocks.enumerated() {
            let cb = Styles.checkbox(block.0, checked: block.2, target: self, action: #selector(timeBlockToggled(_:)))
            cb.tag = 200 + index
            timeStack.addArrangedSubview(cb)
        }

        let timeSection = NSStackView(views: [timeLabel, timeStack])
        timeSection.orientation = .vertical
        timeSection.alignment = .leading
        timeSection.spacing = Styles.itemSpacing

        // Max Concurrent Browsers
        let browserLabel = Styles.sectionHeader("Max Concurrent Browsers")
        let browserSegment = NSSegmentedControl(labels: ["1", "2", "3"], trackingMode: .selectOne, target: self, action: #selector(maxBrowsersChanged(_:)))
        browserSegment.selectedSegment = settings.maxConcurrentBrowsers - 1
        browserSegment.segmentDistribution = .fillEqually
        browserSegment.tag = 300

        let browserStack = NSStackView(views: [browserLabel, browserSegment])
        browserStack.orientation = .vertical
        browserStack.alignment = .leading
        browserStack.spacing = Styles.itemSpacing

        // Launch at Login
        let loginCb = Styles.checkbox("Launch at Login", checked: settings.launchAtLogin, target: self, action: #selector(launchAtLoginToggled(_:)))
        loginCb.tag = 400

        stack.addArrangedSubview(activityStack)
        stack.addArrangedSubview(timeSection)
        stack.addArrangedSubview(browserStack)
        stack.addArrangedSubview(loginCb)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Styles.windowPadding),
        ])

        item.view = container
        return item
    }

    // MARK: - Search Tab

    private func makeSearchTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Search"
        item.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")

        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.itemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settings = SettingsManager.shared.current

        let header = Styles.sectionHeader("Search Engines")
        stack.addArrangedSubview(header)

        let googleCb = Styles.checkbox("Google", checked: settings.searchGoogle, target: self, action: #selector(searchSettingToggled(_:)))
        googleCb.tag = 500
        stack.addArrangedSubview(googleCb)

        let bingCb = Styles.checkbox("Bing", checked: settings.searchBing, target: self, action: #selector(searchSettingToggled(_:)))
        bingCb.tag = 501
        stack.addArrangedSubview(bingCb)

        let ddgCb = Styles.checkbox("DuckDuckGo", checked: settings.searchDuckDuckGo, target: self, action: #selector(searchSettingToggled(_:)))
        ddgCb.tag = 502
        stack.addArrangedSubview(ddgCb)

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        let behaviorHeader = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorHeader)

        let burstCb = Styles.checkbox("Burst mode (related query clusters)", checked: settings.searchBurstMode, target: self, action: #selector(searchSettingToggled(_:)))
        burstCb.tag = 503
        stack.addArrangedSubview(burstCb)

        let clickCb = Styles.checkbox("Click through to results", checked: settings.searchClickThrough, target: self, action: #selector(searchSettingToggled(_:)))
        clickCb.tag = 504
        stack.addArrangedSubview(clickCb)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Styles.windowPadding),
        ])

        item.view = container
        return item
    }

    // MARK: - Shopping Tab

    private func makeShoppingTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Shopping"
        item.image = NSImage(systemSymbolName: "cart", accessibilityDescription: "Shopping")

        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.itemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settings = SettingsManager.shared.current

        let siteNote = Styles.label("Browses Amazon.com \u{2014} searches for products, views pages, scrolls images and reviews.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(siteNote)

        // Products per session stepper
        let productsLabel = Styles.sectionHeader("Products per session")
        let productsStepper = makeStepperRow(value: settings.shoppingProductsPerSession, min: 1, max: 4, tag: 600)

        let productsStack = NSStackView(views: [productsLabel, productsStepper])
        productsStack.orientation = .vertical
        productsStack.alignment = .leading
        productsStack.spacing = Styles.itemSpacing
        stack.addArrangedSubview(productsStack)

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        let behaviorHeader = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorHeader)

        let imagesCb = Styles.checkbox("Browse product images", checked: settings.shoppingBrowseImages, target: self, action: #selector(shoppingSettingToggled(_:)))
        imagesCb.tag = 610
        stack.addArrangedSubview(imagesCb)

        let reviewsCb = Styles.checkbox("Scroll to reviews", checked: settings.shoppingScrollToReviews, target: self, action: #selector(shoppingSettingToggled(_:)))
        reviewsCb.tag = 611
        stack.addArrangedSubview(reviewsCb)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Styles.windowPadding),
        ])

        item.view = container
        return item
    }

    // MARK: - Video Tab

    private func makeVideoTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Video"
        item.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "Video")

        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.itemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settings = SettingsManager.shared.current

        let siteNote = Styles.label("Watches YouTube.com videos \u{2014} muted, with realistic watch durations and ad skipping.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(siteNote)

        // Max watch duration
        let durationLabel = Styles.sectionHeader("Max watch duration")
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

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        let behaviorHeader = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorHeader)

        let skipAdsCb = Styles.checkbox("Auto-skip ads", checked: settings.videoAutoSkipAds, target: self, action: #selector(videoSettingToggled(_:)))
        skipAdsCb.tag = 710
        stack.addArrangedSubview(skipAdsCb)

        let muteCb = Styles.checkbox("Mute videos", checked: settings.videoMute, target: self, action: #selector(videoSettingToggled(_:)))
        muteCb.tag = 711
        stack.addArrangedSubview(muteCb)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Styles.windowPadding),
        ])

        item.view = container
        return item
    }

    // MARK: - News Tab

    private func makeNewsTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "News"
        item.image = NSImage(systemSymbolName: "newspaper", accessibilityDescription: "News")

        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.itemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settings = SettingsManager.shared.current

        let siteNote = Styles.label("Reads articles from news sites defined in your persona. See Sites & Privacy to view or change them.", font: Styles.captionFont, color: Styles.secondaryLabel)
        stack.addArrangedSubview(siteNote)

        // Articles per session
        let articlesLabel = Styles.sectionHeader("Articles per session")
        let articlesStepper = makeStepperRow(value: settings.newsArticlesPerSession, min: 1, max: 5, tag: 800)

        let articlesStack = NSStackView(views: [articlesLabel, articlesStepper])
        articlesStack.orientation = .vertical
        articlesStack.alignment = .leading
        articlesStack.spacing = Styles.itemSpacing
        stack.addArrangedSubview(articlesStack)

        // Sites per session
        let sitesLabel = Styles.sectionHeader("Sites per session")
        let sitesStepper = makeStepperRow(value: settings.newsSitesPerSession, min: 1, max: 3, tag: 810)

        let sitesStack = NSStackView(views: [sitesLabel, sitesStepper])
        sitesStack.orientation = .vertical
        sitesStack.alignment = .leading
        sitesStack.spacing = Styles.itemSpacing
        stack.addArrangedSubview(sitesStack)

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        let behaviorHeader = Styles.sectionHeader("Behavior")
        stack.addArrangedSubview(behaviorHeader)

        let followCb = Styles.checkbox("Follow related links", checked: settings.newsFollowRelatedLinks, target: self, action: #selector(newsSettingToggled(_:)))
        followCb.tag = 820
        stack.addArrangedSubview(followCb)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Styles.windowPadding),
        ])

        item.view = container
        return item
    }

    // MARK: - Sites & Privacy Tab

    private func makeSitesTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Sites & Privacy"
        item.image = NSImage(systemSymbolName: "globe.badge.chevron.backward", accessibilityDescription: "Sites")

        let settings = SettingsManager.shared.current

        // Use a scroll view so all content is reachable
        let outerScroll = NSScrollView()
        outerScroll.hasVerticalScroller = true
        outerScroll.drawsBackground = false
        outerScroll.borderType = .noBorder

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        // --- Section 1: Sites visited (editable) ---
        let sitesHeader = Styles.sectionHeader("Sites Your Roommate Visits")
        let sitesDesc = Styles.label(
            "One URL per line. Add sites to browse, or remove ones you don\u{2019}t want visited.",
            font: Styles.captionFont,
            color: Styles.secondaryLabel
        )

        let sitesScrollView = NSScrollView()
        sitesScrollView.translatesAutoresizingMaskIntoConstraints = false
        sitesScrollView.hasVerticalScroller = true
        sitesScrollView.borderType = .bezelBorder

        let sitesTextView = NSTextView()
        sitesTextView.string = settings.effectiveVisitedSites.joined(separator: "\n")
        sitesTextView.isEditable = true
        sitesTextView.isSelectable = true
        sitesTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        sitesTextView.isVerticallyResizable = true
        sitesTextView.isHorizontallyResizable = false
        sitesTextView.autoresizingMask = [.width]
        sitesTextView.textContainer?.widthTracksTextView = true
        sitesTextView.delegate = self
        sitesScrollView.documentView = sitesTextView
        visitedSitesTextView = sitesTextView

        NSLayoutConstraint.activate([
            sitesScrollView.heightAnchor.constraint(equalToConstant: 120),
            sitesScrollView.widthAnchor.constraint(equalToConstant: 470),
        ])

        let sitesNote = Styles.label(
            "Search results and in-article links may also lead to other sites.",
            font: Styles.captionFont,
            color: Styles.tertiaryLabel
        )

        let sitesSection = NSStackView(views: [sitesHeader, sitesDesc, sitesScrollView, sitesNote])
        sitesSection.orientation = .vertical
        sitesSection.alignment = .leading
        sitesSection.spacing = Styles.itemSpacing
        stack.addArrangedSubview(sitesSection)

        let sep1 = NSBox()
        sep1.boxType = .separator
        stack.addArrangedSubview(sep1)

        // --- Section 2: Blocked Domains (editable) ---
        let blockedHeader = Styles.sectionHeader("Blocked Domains")
        let blockedDesc = Styles.label(
            "Domains your roommate will never visit. One per line.",
            font: Styles.captionFont,
            color: Styles.secondaryLabel
        )

        let blockedScrollView = NSScrollView()
        blockedScrollView.translatesAutoresizingMaskIntoConstraints = false
        blockedScrollView.hasVerticalScroller = true
        blockedScrollView.borderType = .bezelBorder

        let blockedTextView = NSTextView()
        blockedTextView.string = settings.blockedDomains.joined(separator: "\n")
        blockedTextView.isEditable = true
        blockedTextView.isSelectable = true
        blockedTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        blockedTextView.isVerticallyResizable = true
        blockedTextView.isHorizontallyResizable = false
        blockedTextView.autoresizingMask = [.width]
        blockedTextView.textContainer?.widthTracksTextView = true
        blockedTextView.delegate = self
        blockedScrollView.documentView = blockedTextView
        blockedDomainsTextView = blockedTextView

        NSLayoutConstraint.activate([
            blockedScrollView.heightAnchor.constraint(equalToConstant: 72),
            blockedScrollView.widthAnchor.constraint(equalToConstant: 470),
        ])

        let blockedExample = Styles.label(
            "Example: facebook.com, reddit.com",
            font: Styles.captionFont,
            color: Styles.tertiaryLabel
        )

        let blockedSection = NSStackView(views: [blockedHeader, blockedDesc, blockedScrollView, blockedExample])
        blockedSection.orientation = .vertical
        blockedSection.alignment = .leading
        blockedSection.spacing = Styles.itemSpacing
        stack.addArrangedSubview(blockedSection)

        // Assemble: stack inside documentView inside scroll view
        documentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -Styles.windowPadding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Styles.windowPadding),
        ])

        outerScroll.documentView = documentView

        // documentView needs a width constraint so the content lays out properly
        let clipView = outerScroll.contentView
        documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor).isActive = true

        item.view = outerScroll
        return item
    }

    // MARK: - Persona Tab

    private func makePersonaTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Persona"
        item.image = NSImage(systemSymbolName: "person.text.rectangle", accessibilityDescription: "Persona")

        let persona = Persona.loadDefault()

        // Outer scroll view — this tab has a lot of content
        let outerScroll = NSScrollView()
        outerScroll.hasVerticalScroller = true
        outerScroll.drawsBackground = false
        outerScroll.borderType = .noBorder

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Styles.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

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
        let sep0 = NSBox(); sep0.boxType = .separator
        stack.addArrangedSubview(sep0)

        let interestsHeader = Styles.sectionHeader("Interests")
        let interestsDesc = Styles.label("One per line. Shapes search and browsing behavior.", font: Styles.captionFont, color: Styles.secondaryLabel)
        let (interestsScroll, interestsTV) = makeEditableTextArea(
            content: persona.interests.joined(separator: "\n"), height: 70
        )
        let interestsSection = NSStackView(views: [interestsHeader, interestsDesc, interestsScroll])
        interestsSection.orientation = .vertical
        interestsSection.alignment = .leading
        interestsSection.spacing = Styles.itemSpacing
        stack.addArrangedSubview(interestsSection)

        // --- Search Topics ---
        let sep1 = NSBox(); sep1.boxType = .separator
        stack.addArrangedSubview(sep1)

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

            // Small gap between topic groups
            if i < persona.searchTopics.count - 1 {
                let gap = NSView()
                gap.translatesAutoresizingMaskIntoConstraints = false
                gap.heightAnchor.constraint(equalToConstant: 4).isActive = true
                stack.addArrangedSubview(gap)
            }
        }

        // --- Shopping ---
        let sep2 = NSBox(); sep2.boxType = .separator
        stack.addArrangedSubview(sep2)

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
        let sep3 = NSBox(); sep3.boxType = .separator
        stack.addArrangedSubview(sep3)

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
        let sep4 = NSBox(); sep4.boxType = .separator
        stack.addArrangedSubview(sep4)

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

        // Layout
        documentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Styles.windowPadding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Styles.windowPadding),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -Styles.windowPadding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Styles.windowPadding),
        ])

        outerScroll.documentView = documentView
        let clipView = outerScroll.contentView
        documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor).isActive = true

        item.view = outerScroll
        return item
    }

    // MARK: - Helpers

    /// Creates a scrollable editable text area (reusable across tabs)
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

        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height),
            scrollView.widthAnchor.constraint(equalToConstant: 470),
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

    // MARK: - Stepper Helper

    private func makeStepperRow(value: Int, min: Int, max: Int, tag: Int) -> NSStackView {
        let valueLabel = NSTextField(labelWithString: "\(value)")
        valueLabel.font = Styles.headlineFont
        valueLabel.tag = tag + 1 // label tag = stepper tag + 1

        let stepper = NSStepper()
        stepper.minValue = Double(min)
        stepper.maxValue = Double(max)
        stepper.integerValue = value
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.tag = tag
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))

        let row = NSStackView(views: [valueLabel, stepper])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    // MARK: - Actions — General Tab

    @objc private func activityLevelChanged(_ sender: NSSegmentedControl) {
        let levels = AppSettings.ActivityLevel.allCases
        guard sender.selectedSegment < levels.count else { return }
        SettingsManager.shared.update { $0.activityLevel = levels[sender.selectedSegment] }
    }

    @objc private func timeBlockToggled(_ sender: NSButton) {
        let on = sender.state == .on
        let index = sender.tag - 200
        SettingsManager.shared.update { settings in
            switch index {
            case 0: settings.morningEnabled = on
            case 1: settings.afternoonEnabled = on
            case 2: settings.eveningEnabled = on
            case 3: settings.lateNightEnabled = on
            case 4: settings.vampireEnabled = on
            case 5: settings.earlyMorningEnabled = on
            default: break
            }
        }
    }

    @objc private func maxBrowsersChanged(_ sender: NSSegmentedControl) {
        SettingsManager.shared.update { $0.maxConcurrentBrowsers = sender.selectedSegment + 1 }
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        let on = sender.state == .on
        SettingsManager.shared.update { $0.launchAtLogin = on }
        SettingsManager.shared.syncLaunchAtLogin()
    }

    // MARK: - Actions — Search Tab

    @objc private func searchSettingToggled(_ sender: NSButton) {
        let on = sender.state == .on
        SettingsManager.shared.update { settings in
            switch sender.tag {
            case 500: settings.searchGoogle = on
            case 501: settings.searchBing = on
            case 502: settings.searchDuckDuckGo = on
            case 503: settings.searchBurstMode = on
            case 504: settings.searchClickThrough = on
            default: break
            }
        }
    }

    // MARK: - Actions — Shopping Tab

    @objc private func shoppingSettingToggled(_ sender: NSButton) {
        let on = sender.state == .on
        SettingsManager.shared.update { settings in
            switch sender.tag {
            case 610: settings.shoppingBrowseImages = on
            case 611: settings.shoppingScrollToReviews = on
            default: break
            }
        }
    }

    // MARK: - Actions — Video Tab

    @objc private func videoDurationChanged(_ sender: NSSegmentedControl) {
        let values = [2, 5, 10, 15]
        guard sender.selectedSegment < values.count else { return }
        SettingsManager.shared.update { $0.videoMaxWatchMinutes = values[sender.selectedSegment] }
    }

    @objc private func videoSettingToggled(_ sender: NSButton) {
        let on = sender.state == .on
        SettingsManager.shared.update { settings in
            switch sender.tag {
            case 710: settings.videoAutoSkipAds = on
            case 711: settings.videoMute = on
            default: break
            }
        }
    }

    // MARK: - Actions — News Tab

    @objc private func newsSettingToggled(_ sender: NSButton) {
        let on = sender.state == .on
        SettingsManager.shared.update { $0.newsFollowRelatedLinks = on }
    }

    // MARK: - Actions — Steppers

    @objc private func stepperChanged(_ sender: NSStepper) {
        let value = sender.integerValue

        // Update the paired label (tag + 1)
        if let label = sender.superview?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == sender.tag + 1 }) {
            label.stringValue = "\(value)"
        }

        SettingsManager.shared.update { settings in
            switch sender.tag {
            case 600: settings.shoppingProductsPerSession = value
            case 800: settings.newsArticlesPerSession = value
            case 810: settings.newsSitesPerSession = value
            default: break
            }
        }
    }

    // MARK: - Actions — Sites & Privacy Tab

    /// Save text view contents when the view loses focus
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

    @objc private func openPersonaFile(_ sender: NSButton) {
        let path = Persona.activePersonaFilePath
        Persona.ensureDefaultExists()
        NSWorkspace.shared.open(path)
    }

    // MARK: - Actions — Persona Tab

    @objc private func personaPickerChanged(_ sender: NSPopUpButton) {
        guard let selectedName = sender.titleOfSelectedItem else { return }
        SettingsManager.shared.update {
            $0.activePersonaName = selectedName
            $0.visitedSites = []  // Reset so new persona's defaults take effect
        }
        refreshAllTabs()
        tabView.selectTabViewItem(at: 6)
    }

    @objc private func randomizePersona(_ sender: NSButton) {
        let newPersona = PersonaGenerator.randomPersona()
        Persona.save(newPersona, named: newPersona.name)
        SettingsManager.shared.update {
            $0.activePersonaName = newPersona.name
            $0.visitedSites = []
        }
        refreshAllTabs()
        tabView.selectTabViewItem(at: 6)
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

        // Save to the active persona file
        Persona.save(newPersona, named: activeName)

        // Visual feedback
        sender.title = "Saved!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sender.title = "Save Changes"
        }
    }
}
