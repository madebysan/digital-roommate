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

    static let titleFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
    static let headlineFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    static let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let captionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let smallBoldFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    // MARK: - Spacing

    static let windowPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let cardCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 12

    // MARK: - Window Sizes

    static let onboardingSize = NSSize(width: 560, height: 440)
    static let settingsSize = NSSize(width: 560, height: 580)
    static let helpSize = NSSize(width: 520, height: 560)

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
}
