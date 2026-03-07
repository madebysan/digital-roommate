import SwiftUI

// SwiftUI "About Digital Roommate" view. Replaces the old AppKit HelpWindowController content.

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // How It Works
                sectionHeader("How It Works")

                Text("The app runs hidden browser sessions in the background using time-aware scheduling. Activity levels vary throughout the day just like a real person \u{2014} more active in the afternoon, quieter late at night.")
                    .foregroundStyle(.secondary)

                Divider()

                // Modules
                sectionHeader("Modules")

                moduleCard(icon: "magnifyingglass", name: "Search Noise",
                    description: "Runs searches on Google, Bing, and DuckDuckGo using your persona\u{2019}s interests. Sometimes does multi-query research bursts. Clicks through to results to create realistic browsing trails.")

                moduleCard(icon: "cart", name: "Shopping Noise",
                    description: "Browses Amazon \u{2014} searches for products, views product pages, scrolls through images and reviews. Creates the impression of an active online shopper.")

                moduleCard(icon: "play.rectangle", name: "Video Noise",
                    description: "Watches YouTube videos from your persona\u{2019}s interests. Plays muted, watches variable durations (30\u{2013}90% of each video), and skips ads automatically.")

                moduleCard(icon: "newspaper", name: "News & Browsing",
                    description: "Visits news sites, reads articles at realistic speed, and occasionally follows related links. Covers general, tech, hobby, and professional sites.")

                Divider()

                // Customizing the Persona
                sectionHeader("Customizing the Persona")

                Text("The fake persona (name, interests, shopping habits, video topics) defines what kind of person your traffic looks like. To customize it:")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    bulletItem("Open Settings \u{2192} Persona")
                    bulletItem("Edit the name, interests, search topics, shopping terms, and video queries")
                    bulletItem("Click Save Changes \u{2014} takes effect on the next browsing session")
                }

                Text("Use Settings \u{2192} Sites & Privacy to see which sites the roommate visits and block specific domains.")
                    .foregroundStyle(.secondary)

                Divider()

                // Settings
                sectionHeader("Settings")

                Text("Use Settings (in the menu bar dropdown) to control activity level, active time blocks, and per-module options like which search engines to use, video watch duration, and more.")
                    .foregroundStyle(.secondary)

                Divider()

                // Footer
                Text("Digital Roommate \u{2014} Your data is your own.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                // Made by credit
                Button {
                    if let url = URL(string: "https://santiagoalonso.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 0) {
                        Text("Made by ")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("santiagoalonso.com")
                            .font(.caption)
                            .foregroundStyle(.link)
                            .underline()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .frame(width: 520, height: 720)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 8)

            Text("Digital Roommate")
                .font(.system(size: 26, weight: .bold))

            Text("Privacy noise generator for macOS")
                .foregroundStyle(.secondary)

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            Text("Version \(version) (\(build))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Text("Digital Roommate creates realistic web traffic from a fake persona, making it look like another person lives in your house. This poisons ISP-level and data-broker profiling by adding convincing decoy activity alongside your real browsing.")
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
    }

    private func moduleCard(icon: String, name: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 15, weight: .medium))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    private func bulletItem(_ text: String) -> some View {
        Text("\u{2022}  \(text)")
            .foregroundStyle(.secondary)
    }
}
