import SwiftUI
import ServiceManagement

// SwiftUI-based Settings window. Replaces the old AppKit SettingsWindowController
// with native macOS form styling, sidebar navigation, and grouped controls.

// MARK: - Observable Settings Model

/// Bridges SettingsManager (non-reactive) to SwiftUI's @Observable.
/// Reads current settings on init, writes back on every change.
@Observable
class SettingsViewModel {
    // General
    var activityLevel: AppSettings.ActivityLevel
    var morningEnabled: Bool
    var afternoonEnabled: Bool
    var eveningEnabled: Bool
    var lateNightEnabled: Bool
    var vampireEnabled: Bool
    var earlyMorningEnabled: Bool
    var maxConcurrentBrowsers: Int
    var launchAtLogin: Bool

    // Search
    var searchGoogle: Bool
    var searchBing: Bool
    var searchDuckDuckGo: Bool
    var searchBurstMode: Bool
    var searchClickThrough: Bool

    // Shopping
    var shoppingProductsPerSession: Int
    var shoppingBrowseImages: Bool
    var shoppingScrollToReviews: Bool

    // Video
    var videoMaxWatchMinutes: Int
    var videoAutoSkipAds: Bool
    var videoMute: Bool

    // News
    var newsArticlesPerSession: Int
    var newsSitesPerSession: Int
    var newsFollowRelatedLinks: Bool

    // Sites & Privacy
    var visitedSitesText: String
    var blockedDomainsText: String

    // Persona
    var activePersonaName: String
    var availablePersonas: [String]
    var persona: Persona

    // Persona editing fields
    var personaInterests: String
    var personaSearchTopics: [EditableSearchTopic]
    var personaShoppingCategories: [EditableShoppingCategory]
    var personaVideoInterests: [EditableVideoInterest]

    // UI state
    var saveButtonLabel: String = "Save Changes"
    var saveButtonTinted: Bool = false

    struct EditableSearchTopic: Identifiable {
        let id = UUID()
        var category: String
        var items: String
        var originalTemplates: [String]
    }

    struct EditableShoppingCategory: Identifiable {
        let id = UUID()
        var name: String
        var searchTerms: String
        var originalProductUrls: [String]
    }

    struct EditableVideoInterest: Identifiable {
        let id = UUID()
        var topic: String
        var searchQueries: String
        var originalChannelUrls: [String]
        var originalVideoUrls: [String]
    }

    init() {
        let s = SettingsManager.shared.current
        activityLevel = s.activityLevel
        morningEnabled = s.morningEnabled
        afternoonEnabled = s.afternoonEnabled
        eveningEnabled = s.eveningEnabled
        lateNightEnabled = s.lateNightEnabled
        vampireEnabled = s.vampireEnabled
        earlyMorningEnabled = s.earlyMorningEnabled
        maxConcurrentBrowsers = s.maxConcurrentBrowsers
        launchAtLogin = s.launchAtLogin

        searchGoogle = s.searchGoogle
        searchBing = s.searchBing
        searchDuckDuckGo = s.searchDuckDuckGo
        searchBurstMode = s.searchBurstMode
        searchClickThrough = s.searchClickThrough

        shoppingProductsPerSession = s.shoppingProductsPerSession
        shoppingBrowseImages = s.shoppingBrowseImages
        shoppingScrollToReviews = s.shoppingScrollToReviews

        videoMaxWatchMinutes = s.videoMaxWatchMinutes
        videoAutoSkipAds = s.videoAutoSkipAds
        videoMute = s.videoMute

        newsArticlesPerSession = s.newsArticlesPerSession
        newsSitesPerSession = s.newsSitesPerSession
        newsFollowRelatedLinks = s.newsFollowRelatedLinks

        visitedSitesText = s.visitedSites.joined(separator: "\n")
        blockedDomainsText = s.blockedDomains.joined(separator: "\n")

        activePersonaName = s.activePersonaName
        availablePersonas = Persona.listAll()

        let p = Persona.loadDefault()
        persona = p

        personaInterests = p.interests.joined(separator: "\n")
        personaSearchTopics = p.searchTopics.map {
            EditableSearchTopic(category: $0.category, items: $0.items.joined(separator: "\n"), originalTemplates: $0.templates)
        }
        personaShoppingCategories = p.shoppingCategories.map {
            EditableShoppingCategory(name: $0.name, searchTerms: $0.searchTerms.joined(separator: "\n"), originalProductUrls: $0.productUrls)
        }
        personaVideoInterests = p.videoInterests.map {
            EditableVideoInterest(topic: $0.topic, searchQueries: $0.searchQueries.joined(separator: "\n"), originalChannelUrls: $0.channelUrls, originalVideoUrls: $0.videoUrls)
        }
    }

    /// Persist a single setting change immediately
    func save() {
        SettingsManager.shared.update { s in
            s.activityLevel = activityLevel
            s.morningEnabled = morningEnabled
            s.afternoonEnabled = afternoonEnabled
            s.eveningEnabled = eveningEnabled
            s.lateNightEnabled = lateNightEnabled
            s.vampireEnabled = vampireEnabled
            s.earlyMorningEnabled = earlyMorningEnabled
            s.maxConcurrentBrowsers = maxConcurrentBrowsers
            s.launchAtLogin = launchAtLogin

            s.searchGoogle = searchGoogle
            s.searchBing = searchBing
            s.searchDuckDuckGo = searchDuckDuckGo
            s.searchBurstMode = searchBurstMode
            s.searchClickThrough = searchClickThrough

            s.shoppingProductsPerSession = shoppingProductsPerSession
            s.shoppingBrowseImages = shoppingBrowseImages
            s.shoppingScrollToReviews = shoppingScrollToReviews

            s.videoMaxWatchMinutes = videoMaxWatchMinutes
            s.videoAutoSkipAds = videoAutoSkipAds
            s.videoMute = videoMute

            s.newsArticlesPerSession = newsArticlesPerSession
            s.newsSitesPerSession = newsSitesPerSession
            s.newsFollowRelatedLinks = newsFollowRelatedLinks
        }
    }

    /// Split a newline-delimited text field into trimmed, non-empty lines.
    private func splitLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func saveSites() {
        let visited = splitLines(visitedSitesText)
        let blocked = splitLines(blockedDomainsText)
        SettingsManager.shared.update { s in
            s.visitedSites = visited
            s.blockedDomains = blocked
        }
    }

    func syncLaunchAtLogin() {
        SettingsManager.shared.update { $0.launchAtLogin = launchAtLogin }
        SettingsManager.shared.syncLaunchAtLogin()
    }

    func switchPersona(to name: String) {
        activePersonaName = name
        SettingsManager.shared.update { s in
            s.activePersonaName = name
            s.visitedSites = []
        }
        visitedSitesText = ""
        reloadPersona()
    }

    func randomizePersona() {
        let newPersona = PersonaGenerator.randomPersona()
        Persona.save(newPersona, named: newPersona.name)
        activePersonaName = newPersona.name
        SettingsManager.shared.update { s in
            s.activePersonaName = newPersona.name
            s.visitedSites = []
        }
        visitedSitesText = ""
        availablePersonas = Persona.listAll()
        reloadPersona()
    }

    func savePersona() {
        let interests = splitLines(personaInterests)

        let searchTopics = personaSearchTopics.map { topic in
            Persona.SearchTopic(
                category: topic.category,
                templates: topic.originalTemplates,
                items: splitLines(topic.items)
            )
        }

        let shoppingCategories = personaShoppingCategories.map { cat in
            Persona.ShoppingCategory(
                name: cat.name,
                searchTerms: splitLines(cat.searchTerms),
                productUrls: cat.originalProductUrls
            )
        }

        let videoInterests = personaVideoInterests.map { vi in
            Persona.VideoInterest(
                topic: vi.topic,
                channelUrls: vi.originalChannelUrls,
                videoUrls: vi.originalVideoUrls,
                searchQueries: splitLines(vi.searchQueries)
            )
        }

        let updated = Persona(
            name: activePersonaName,
            age: persona.age,
            profession: persona.profession,
            interests: interests,
            searchTopics: searchTopics,
            shoppingCategories: shoppingCategories,
            videoInterests: videoInterests,
            newsSites: persona.newsSites,
            activeHours: persona.activeHours
        )

        Persona.save(updated, named: activePersonaName)
        persona = updated

        // Visual feedback
        saveButtonLabel = "\u{2713} Saved"
        saveButtonTinted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.saveButtonLabel = "Save Changes"
            self?.saveButtonTinted = false
        }
    }

    func exportPersona() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(activePersonaName).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(persona) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func openPersonaFile() {
        NSWorkspace.shared.open(Persona.activePersonaFilePath)
    }

    private func reloadPersona() {
        persona = Persona.loadDefault()
        personaInterests = persona.interests.joined(separator: "\n")
        personaSearchTopics = persona.searchTopics.map {
            EditableSearchTopic(category: $0.category, items: $0.items.joined(separator: "\n"), originalTemplates: $0.templates)
        }
        personaShoppingCategories = persona.shoppingCategories.map {
            EditableShoppingCategory(name: $0.name, searchTerms: $0.searchTerms.joined(separator: "\n"), originalProductUrls: $0.productUrls)
        }
        personaVideoInterests = persona.videoInterests.map {
            EditableVideoInterest(topic: $0.topic, searchQueries: $0.searchQueries.joined(separator: "\n"), originalChannelUrls: $0.channelUrls, originalVideoUrls: $0.videoUrls)
        }
    }
}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case search = "Search"
    case shopping = "Shopping"
    case video = "Video"
    case news = "News"
    case sites = "Sites & Privacy"
    case persona = "Persona"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:  return "gearshape"
        case .search:   return "magnifyingglass"
        case .shopping: return "cart"
        case .video:    return "play.rectangle"
        case .news:     return "newspaper"
        case .sites:    return "globe.badge.chevron.backward"
        case .persona:  return "person.text.rectangle"
        }
    }
}

// MARK: - Auto-Save Modifier

/// Breaks up onChange calls into groups to avoid the SwiftUI type-checker limit.
private struct AutoSaveModifier: ViewModifier {
    @Bindable var vm: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .modifier(GeneralSaveGroup(vm: vm))
            .modifier(SearchSaveGroup(vm: vm))
            .modifier(ShoppingVideoNewsSaveGroup(vm: vm))
    }
}

private struct GeneralSaveGroup: ViewModifier {
    @Bindable var vm: SettingsViewModel
    func body(content: Content) -> some View {
        content
            .onChange(of: vm.activityLevel) { vm.save() }
            .onChange(of: vm.morningEnabled) { vm.save() }
            .onChange(of: vm.afternoonEnabled) { vm.save() }
            .onChange(of: vm.eveningEnabled) { vm.save() }
            .onChange(of: vm.lateNightEnabled) { vm.save() }
            .onChange(of: vm.vampireEnabled) { vm.save() }
            .onChange(of: vm.earlyMorningEnabled) { vm.save() }
            .onChange(of: vm.maxConcurrentBrowsers) { vm.save() }
            .onChange(of: vm.launchAtLogin) { vm.syncLaunchAtLogin() }
    }
}

private struct SearchSaveGroup: ViewModifier {
    @Bindable var vm: SettingsViewModel
    func body(content: Content) -> some View {
        content
            .onChange(of: vm.searchGoogle) { vm.save() }
            .onChange(of: vm.searchBing) { vm.save() }
            .onChange(of: vm.searchDuckDuckGo) { vm.save() }
            .onChange(of: vm.searchBurstMode) { vm.save() }
            .onChange(of: vm.searchClickThrough) { vm.save() }
    }
}

private struct ShoppingVideoNewsSaveGroup: ViewModifier {
    @Bindable var vm: SettingsViewModel
    func body(content: Content) -> some View {
        content
            .onChange(of: vm.shoppingProductsPerSession) { vm.save() }
            .onChange(of: vm.shoppingBrowseImages) { vm.save() }
            .onChange(of: vm.shoppingScrollToReviews) { vm.save() }
            .onChange(of: vm.videoMaxWatchMinutes) { vm.save() }
            .onChange(of: vm.videoAutoSkipAds) { vm.save() }
            .onChange(of: vm.videoMute) { vm.save() }
            .onChange(of: vm.newsArticlesPerSession) { vm.save() }
            .onChange(of: vm.newsSitesPerSession) { vm.save() }
            .onChange(of: vm.newsFollowRelatedLinks) { vm.save() }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var vm = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            ScrollView {
                detailContent
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 620)
        .toolbar(removing: .sidebarToggle)
        .modifier(AutoSaveModifier(vm: vm))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .general:  generalSection
        case .search:   searchSection
        case .shopping: shoppingSection
        case .video:    videoSection
        case .news:     newsSection
        case .sites:    sitesSection
        case .persona:  personaSection
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General").font(.title2).fontWeight(.bold)

            // Activity Level
            GroupBox("Activity Level") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Level", selection: $vm.activityLevel) {
                        ForEach(AppSettings.ActivityLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(vm.activityLevel.sessionsPerHour)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Schedule
            GroupBox("Active Time Blocks") {
                VStack(alignment: .leading, spacing: 4) {
                    scheduleRow("Morning", subtitle: "6 AM \u{2013} 12 PM", isOn: $vm.morningEnabled)
                    Divider()
                    scheduleRow("Afternoon", subtitle: "12 \u{2013} 6 PM", isOn: $vm.afternoonEnabled)
                    Divider()
                    scheduleRow("Evening", subtitle: "6 \u{2013} 11 PM", isOn: $vm.eveningEnabled)
                    Divider()
                    scheduleRow("Late Night", subtitle: "11 PM \u{2013} 1 AM", isOn: $vm.lateNightEnabled)
                    Divider()
                    scheduleRow("Vampire", subtitle: "1 \u{2013} 5 AM", isOn: $vm.vampireEnabled)
                    Divider()
                    scheduleRow("Early Morning", subtitle: "5 \u{2013} 6 AM", isOn: $vm.earlyMorningEnabled)
                }
                .padding(.vertical, 4)
            }

            // Browser & Launch
            GroupBox("System") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max concurrent browsers")
                        Spacer()
                        Picker("", selection: $vm.maxConcurrentBrowsers) {
                            ForEach(1...3, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .frame(width: 60)
                    }
                    .padding(.vertical, 2)
                    Divider()
                    settingsToggle("Launch at login", isOn: $vm.launchAtLogin)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func scheduleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Search").font(.title2).fontWeight(.bold)

            GroupBox("Search Engines") {
                VStack(alignment: .leading, spacing: 4) {
                    settingsToggle("Google", isOn: $vm.searchGoogle)
                    Divider()
                    settingsToggle("Bing", isOn: $vm.searchBing)
                    Divider()
                    settingsToggle("DuckDuckGo", isOn: $vm.searchDuckDuckGo)
                }
                .padding(.vertical, 4)
            }

            GroupBox("Behavior") {
                VStack(alignment: .leading, spacing: 4) {
                    settingsToggle("Burst mode (related query clusters)", isOn: $vm.searchBurstMode)
                    Divider()
                    settingsToggle("Click through to results", isOn: $vm.searchClickThrough)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Shopping

    private var shoppingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Shopping").font(.title2).fontWeight(.bold)

            moduleInfoBox(
                icon: "cart", color: .blue,
                text: "Browses Amazon.com \u{2014} searches for products, views pages, scrolls images and reviews."
            )

            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Products per session")
                        Spacer()
                        Picker("", selection: $vm.shoppingProductsPerSession) {
                            ForEach(1...4, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .frame(width: 60)
                    }
                    .padding(.vertical, 2)
                    Divider()
                    settingsToggle("Browse product images", isOn: $vm.shoppingBrowseImages)
                    Divider()
                    settingsToggle("Scroll to reviews", isOn: $vm.shoppingScrollToReviews)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Video

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Video").font(.title2).fontWeight(.bold)

            moduleInfoBox(
                icon: "play.rectangle", color: .red,
                text: "Watches YouTube.com videos \u{2014} muted, with realistic watch durations and ad skipping."
            )

            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Max watch duration")
                        Picker("", selection: $vm.videoMaxWatchMinutes) {
                            Text("2 min").tag(2)
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                    Divider()
                    settingsToggle("Auto-skip ads", isOn: $vm.videoAutoSkipAds)
                    Divider()
                    settingsToggle("Mute videos", isOn: $vm.videoMute)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - News

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("News").font(.title2).fontWeight(.bold)

            moduleInfoBox(
                icon: "newspaper", color: .orange,
                text: "Reads articles from news sites defined in your persona. Scrolls at a realistic pace and occasionally follows related links."
            )

            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Articles per session")
                        Spacer()
                        Picker("", selection: $vm.newsArticlesPerSession) {
                            ForEach(1...5, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .frame(width: 60)
                    }
                    .padding(.vertical, 2)
                    Divider()
                    HStack {
                        Text("Sites per session")
                        Spacer()
                        Picker("", selection: $vm.newsSitesPerSession) {
                            ForEach(1...3, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .frame(width: 60)
                    }
                    .padding(.vertical, 2)
                    Divider()
                    settingsToggle("Follow related links", isOn: $vm.newsFollowRelatedLinks)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Sites & Privacy

    private var sitesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sites & Privacy").font(.title2).fontWeight(.bold)

            GroupBox("Sites Your Roommate Visits") {
                VStack(alignment: .leading, spacing: 6) {
                    styledTextEditor($vm.visitedSitesText, height: 120, monospaced: true)

                    Text("One URL per line. Leave empty to auto-populate from your persona.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            GroupBox("Blocked Domains") {
                VStack(alignment: .leading, spacing: 6) {
                    styledTextEditor($vm.blockedDomainsText, height: 80, monospaced: true)

                    Text("One domain per line (e.g., facebook.com, reddit.com)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Button("Save Sites") {
                vm.saveSites()
            }
        }
    }

    // MARK: - Persona

    private var personaSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Persona").font(.title2).fontWeight(.bold)

            // Active persona picker + actions
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Active Persona", selection: $vm.activePersonaName) {
                        ForEach(vm.availablePersonas, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onChange(of: vm.activePersonaName) { _, newValue in
                        vm.switchPersona(to: newValue)
                    }

                    HStack(spacing: 8) {
                        Button("Randomize") { vm.randomizePersona() }
                        Button("Export\u{2026}") { vm.exportPersona() }
                        Button("Open File\u{2026}") { vm.openPersonaFile() }
                    }
                }
                .padding(.vertical, 4)
            }

            // Interests
            GroupBox("Interests") {
                styledTextEditor($vm.personaInterests)
                    .padding(.vertical, 4)
            }

            // Search Topics
            Text("Search Topics").font(.headline)

            ForEach($vm.personaSearchTopics) { $topic in
                personaCard {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Category name", text: $topic.category)
                            .textFieldStyle(.plain)
                            .font(.headline)
                        Spacer()
                        Button {
                            let id = topic.id
                            DispatchQueue.main.async { vm.personaSearchTopics.removeAll { $0.id == id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.quaternary)
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("Search items (one per line)")
                        .font(.caption).foregroundStyle(.tertiary)
                    styledTextEditor($topic.items, height: 50)
                }
            }

            Button {
                vm.personaSearchTopics.append(
                    SettingsViewModel.EditableSearchTopic(category: "", items: "", originalTemplates: [])
                )
            } label: {
                Label("Add Search Topic", systemImage: "plus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            Divider().padding(.vertical, 4)

            // Shopping Categories
            Text("Shopping Categories").font(.headline)

            ForEach($vm.personaShoppingCategories) { $cat in
                personaCard {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Category name", text: $cat.name)
                            .textFieldStyle(.plain)
                            .font(.headline)
                        Spacer()
                        Button {
                            let id = cat.id
                            DispatchQueue.main.async { vm.personaShoppingCategories.removeAll { $0.id == id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.quaternary)
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("Search terms (one per line)")
                        .font(.caption).foregroundStyle(.tertiary)
                    styledTextEditor($cat.searchTerms, height: 50)
                }
            }

            Button {
                vm.personaShoppingCategories.append(
                    SettingsViewModel.EditableShoppingCategory(name: "", searchTerms: "", originalProductUrls: [])
                )
            } label: {
                Label("Add Shopping Category", systemImage: "plus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            Divider().padding(.vertical, 4)

            // Video Interests
            Text("Video Interests").font(.headline)

            ForEach($vm.personaVideoInterests) { $vi in
                personaCard {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Topic name", text: $vi.topic)
                            .textFieldStyle(.plain)
                            .font(.headline)
                        Spacer()
                        Button {
                            let id = vi.id
                            DispatchQueue.main.async { vm.personaVideoInterests.removeAll { $0.id == id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.quaternary)
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("YouTube search queries (one per line)")
                        .font(.caption).foregroundStyle(.tertiary)
                    styledTextEditor($vi.searchQueries, height: 50)
                }
            }

            Button {
                vm.personaVideoInterests.append(
                    SettingsViewModel.EditableVideoInterest(topic: "", searchQueries: "", originalChannelUrls: [], originalVideoUrls: [])
                )
            } label: {
                Label("Add Video Interest", systemImage: "plus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            // Save + note
            HStack {
                Button(vm.saveButtonLabel) { vm.savePersona() }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.saveButtonTinted ? .green : nil)

                Text("Changes take effect on the next browsing session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    /// Full-width toggle row: label on the left, switch on the right.
    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }

    /// A lightly styled card for persona groups (search topics, shopping, video).
    private func personaCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Styled multi-line text editor with consistent appearance.
    private func styledTextEditor(_ text: Binding<String>, height: CGFloat = 60, monospaced: Bool = false) -> some View {
        TextEditor(text: text)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            .frame(height: height)
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func moduleInfoBox(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
