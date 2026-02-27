import Cocoa

// An NSView with a flipped (top-left) coordinate origin.
// Required as the documentView of NSScrollView so content
// starts at the top instead of floating at the bottom.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Shared visual constants for all windows (Help, Settings, Onboarding).
// Keeps the look consistent without repeating magic numbers.
enum Styles {

    // MARK: - Colors

    static let accentColor = NSColor.controlAccentColor
    static let secondaryLabel = NSColor.secondaryLabelColor
    static let tertiaryLabel = NSColor.tertiaryLabelColor
    static let windowBackground = NSColor.windowBackgroundColor
    static let cardBackground = NSColor.controlBackgroundColor
    static let separator = NSColor.separatorColor

    // MARK: - Fonts

    static let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
    static let headlineFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    static let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let captionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let smallBoldFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    // MARK: - Spacing

    static let windowPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let cardCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let bottomBarPadding: CGFloat = 16
    static let headerGroupSpacing: CGFloat = 4

    // MARK: - Icon Sizes

    static let heroIconSize: CGFloat = 56
    static let cardIconSize: CGFloat = 20
    static let sidebarIconSize: CGFloat = 13
    static let statusBarIconSize: CGFloat = 16

    // MARK: - Window Sizes

    static let onboardingSize = NSSize(width: 560, height: 460)
    static let settingsSize = NSSize(width: 720, height: 560)
    static let helpSize = NSSize(width: 520, height: 720)

    // MARK: - Sidebar

    static let sidebarWidth: CGFloat = 180

    // MARK: - Helpers

    /// Create a standard label with the given text and font.
    static func label(_ text: String, font: NSFont = bodyFont, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    /// Create a section header label — small, uppercase, tertiary color.
    /// Matches the macOS System Settings wayfinding style: section headers
    /// are structural markers, not content. Card titles (headlineFont) are
    /// the prominent level.
    static func sectionHeader(_ text: String) -> NSTextField {
        let field = label(text.uppercased(), font: smallBoldFont, color: tertiaryLabel)
        // Extra letter spacing for the uppercase wayfinding style
        if let attrStr = field.attributedStringValue.mutableCopy() as? NSMutableAttributedString {
            attrStr.addAttribute(.kern, value: 0.8, range: NSRange(location: 0, length: attrStr.length))
            field.attributedStringValue = attrStr
        }
        return field
    }

    /// Create a checkbox with the given title and initial state.
    static func checkbox(_ title: String, checked: Bool, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: target, action: action)
        button.state = checked ? .on : .off
        button.font = bodyFont
        return button
    }

    /// Create a rounded card-style box view.
    static func cardView() -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = cardCornerRadius
        box.fillColor = cardBackground
        box.borderColor = separator.withAlphaComponent(0.3)
        box.borderWidth = 0.5
        box.titlePosition = .noTitle
        box.contentViewMargins = NSSize(width: cardPadding, height: cardPadding)
        return box
    }

    // MARK: - Settings Card Helpers

    /// A card wrapping a vertical stack of rows. Fills available width.
    /// Uses NSBox so fillColor and borderColor respond to appearance
    /// changes (light/dark mode) automatically.
    static func settingsCard(_ rows: [NSView]) -> NSView {
        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = cardCornerRadius
        card.fillColor = cardBackground
        card.borderColor = separator.withAlphaComponent(0.3)
        card.borderWidth = 0.5
        card.titlePosition = .noTitle
        card.contentViewMargins = .zero

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.contentView?.addSubview(stack)
        if let content = card.contentView {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }

        return card
    }

    /// A thin horizontal divider for inside cards.
    static func cardDivider() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: cardPadding),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -cardPadding),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    /// A row with a label (+ optional subtitle) on the left, and an NSSwitch on the right.
    /// Returns (rowView, toggle) so the caller can set the tag and target/action.
    static func toggleRow(
        title: String,
        subtitle: String? = nil,
        isOn: Bool,
        target: AnyObject?,
        action: Selector
    ) -> (NSView, NSSwitch) {
        let toggle = NSSwitch()
        toggle.state = isOn ? .on : .off
        toggle.target = target
        toggle.action = action
        toggle.controlSize = .small

        let titleLabel = label(title, font: bodyFont)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let leftStack: NSView
        if let subtitle = subtitle {
            let sub = label(subtitle, font: captionFont, color: secondaryLabel)
            sub.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let vStack = NSStackView(views: [titleLabel, sub])
            vStack.orientation = .vertical
            vStack.alignment = .leading
            vStack.spacing = 1
            leftStack = vStack
        } else {
            leftStack = titleLabel
        }

        // Spacer to push toggle to the right
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [leftStack, spacer, toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: cardPadding, bottom: 8, right: cardPadding)

        // Make the row fill available width
        row.translatesAutoresizingMaskIntoConstraints = false

        return (row, toggle)
    }

    /// A reusable module info card: icon on the left, title + description in the middle,
    /// and an optional trailing view (e.g. toggle) on the right. Used in Onboarding and Help.
    /// Uses NSBox so fillColor/borderColor respond to dark mode automatically.
    static func moduleInfoCard(
        icon: String,
        title: String,
        description: String,
        trailingView: NSView? = nil,
        width: CGFloat? = nil
    ) -> NSView {
        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = cardCornerRadius
        card.fillColor = cardBackground
        card.borderColor = separator.withAlphaComponent(0.3)
        card.borderWidth = 0.5
        card.titlePosition = .noTitle
        card.contentViewMargins = .zero

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: cardIconSize, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = accentColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        // Text column
        let nameLabel = label(title, font: headlineFont)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let descLabel = label(description, font: captionFont, color: secondaryLabel)
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = NSStackView(views: [nameLabel, descLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        // Let the text column expand to fill, pushing trailing view to the right
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Row: icon | text | spacer | optional trailing view
        var rowViews: [NSView] = [iconView, textStack]
        if let trailing = trailingView {
            trailing.setContentHuggingPriority(.required, for: .horizontal)
            // Spacer pushes trailing view to the right edge
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rowViews.append(spacer)
            rowViews.append(trailing)
        }

        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 12, left: cardPadding, bottom: 12, right: cardPadding)

        // Add row to NSBox's contentView (not the box itself)
        guard let content = card.contentView else { return card }
        content.addSubview(row)

        var constraints = [
            row.topAnchor.constraint(equalTo: content.topAnchor),
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
        ]

        if let w = width {
            card.translatesAutoresizingMaskIntoConstraints = false
            constraints.append(card.widthAnchor.constraint(equalToConstant: w))
        }

        NSLayoutConstraint.activate(constraints)
        return card
    }

    /// A primary action button styled as the key equivalent (accent-tinted).
    /// Uses the system's built-in button rendering so press/hover/disabled
    /// states work correctly and appearance changes (Dark Mode, accent color)
    /// update automatically.
    static func accentButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.controlSize = .large
        return button
    }

    /// A row with a label on the left and an NSPopUpButton on the right.
    /// Returns (rowView, popup) so the caller can set the tag and configure items.
    static func popupRow(
        title: String,
        items: [String],
        selectedIndex: Int,
        target: AnyObject?,
        action: Selector
    ) -> (NSView, NSPopUpButton) {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.removeAllItems()
        popup.addItems(withTitles: items)
        if selectedIndex >= 0 && selectedIndex < items.count {
            popup.selectItem(at: selectedIndex)
        }
        popup.target = target
        popup.action = action
        popup.controlSize = .regular

        let titleLabel = label(title, font: bodyFont)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [titleLabel, spacer, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: cardPadding, bottom: 8, right: cardPadding)

        row.translatesAutoresizingMaskIntoConstraints = false

        return (row, popup)
    }
}
