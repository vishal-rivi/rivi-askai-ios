import SwiftUI

/// Design-system color tokens. Each token resolves to its light or dark value
/// from the current `colorScheme`, so views adapt to system Dark Mode automatically.
enum AppColor {
    /// Screen background.
    static let background = Color(light: "#FFFFFF", dark: "#171A1C")
    /// Primary text (titles, values).
    static let mainText = Color(light: "#374151", dark: "#FAFAFA")
    /// Secondary text.
    static let subtext = Color(light: "#404346", dark: "#8D9195")
    /// Text inside tag / chip.
    static let tagText = Color(light: "#017ACB", dark: "#F1F8FD")
    /// Tag / chip / tinted highlight fill.
    static let tag = Color(light: "#F1F8FD", dark: "#017ACB")
    /// Default border, divider and separator.
    static let border = Color(light: "#EBF0F5", dark: "#414346")
    /// Border of a selected / focused element.
    static let borderSelection = Color(light: "#017ACB", dark: "#0293D6")
    /// Background behind a group of cards.
    static let cardsBackground = Color(light: "#FAFAFA", dark: "#323335")
    /// Card surface.
    static let cards = Color(light: "#FFFFFF", dark: "#232527")
    /// Selected row / pressed state fill.
    static let selection = Color(light: "#ECEDED", dark: "#414346")
    /// Primary button fill and brand accent (travel UI).
    static let button = Color(light: "#017ACB", dark: "#00A1EB")
    /// Subtle surface (input fields, secondary panels).
    static let color1 = Color(light: "#F8FAFC", dark: "#323335")
    /// Content on filled buttons (always white).
    static let color2 = Color(light: "#FFFFFF", dark: "#FFFFFF")
    /// Tertiary text and icons.
    static let color3 = Color(light: "#63686C", dark: "#CBD5E1")
    /// Placeholder / disabled text and icons.
    static let color4 = Color(light: "#8D9195", dark: "#8D9195")
    /// High-contrast text (headings).
    static let color5 = Color(light: "#171A1C", dark: "#FAFAFA")

    // MARK: - Smart Sort V2 (purple)

    /// Sparkle, Smart Sort label and selected chip accent.
    static let smartSortAccent = Color(light: "#7B3FE4", dark: "#9D74EE")
    /// Tinted fill behind an active Smart Sort label and selected chips.
    static let smartSortTint = Color(light: "#EFE9FD", dark: "#2E2547")
    /// Primary call-to-action fill.
    static let smartSortButton = Color(light: "#6B2FE0", dark: "#7B3FE4")
    /// Call-to-action fill while disabled.
    static let smartSortButtonDisabled = Color(light: "#C6B2F3", dark: "#4A3D6B")
}
