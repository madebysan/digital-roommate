import Cocoa

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

    // MARK: - Window Sizes

    static let onboardingSize = NSSize(width: 560, height: 460)
    static let settingsSize = NSSize(width: 720, height: 560)
    static let helpSize = NSSize(width: 520, height: 560)

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

    /// Create a section header label.
    static func sectionHeader(_ text: String) -> NSTextField {
        return label(text, font: headlineFont)
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
    /// Uses a plain NSView with a layer background — NSBox.contentView replacement
    /// doesn't propagate intrinsic size properly with auto layout.
    static func settingsCard(_ rows: [NSView]) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = cardBackground.cgColor
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = separator.withAlphaComponent(0.3).cgColor

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

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
