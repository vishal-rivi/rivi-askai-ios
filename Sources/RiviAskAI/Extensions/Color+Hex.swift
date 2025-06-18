import SwiftUI

/// Extension for creating SwiftUI Colors from hex strings and handling dynamic color themes
extension Color {
    /// Creates a Color from a hex string
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex) ?? .clear)
    }
    
    /// Creates a dynamic Color that adapts between light and dark mode hex values
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(hex: dark) ?? .black
                default:
                    return UIColor(hex: light) ?? .white
            }
        })
    }
    
    /// Creates a Color from a hex string with custom opacity
    init(hex: String, opacity: Double) {
        self.init(uiColor: UIColor(hex: hex)?.withAlphaComponent(opacity) ?? .clear)
    }
}
