import SwiftUI

extension Color {
    public enum RiviAskAI {
        // Main theme colors
        public static let primary = Color(light: "#018CDE", dark: "#118AD2")      // Default accent color
        public static let background = Color(light: "#FFFFFF", dark: "#000000")   // Main background
        public static let text = Color(light: "#313330", dark: "#F8F7F9")         // Primary text color
        
        // Button colors
        public enum Button {
            public static let background = Color(light: "#F6F6F6", dark: "#2C2C2E")
            public static let backgroundHighlighted = Color(light: "#ECECEC", dark: "#3A3A3C")
            public static let text = Color(light: "#313330", dark: "#F8F7F9")
            public static let icon = Color(light: "#018CDE", dark: "#118AD2")     // Icon color (usually primary)
            public static let border = Color(light: "#E3E4E5", dark: "#444444")
        }
        
        // Input field colors
        public enum Input {
            public static let background = Color(light: "#FFFFFF", dark: "#2C2C2E")
            public static let border = Color(light: "#E3E4E5", dark: "#444444")
            public static let text = Color(light: "#313330", dark: "#F8F7F9")
            public static let placeholder = Color(light: "#B4B6B8", dark: "#8E8E93")
        }
        
        // Popup colors
        public enum Popup {
            public static let background = Color(light: "#FFFFFF", dark: "#1C1C1E")
            public static let headerText = Color(light: "#313330", dark: "#F8F7F9")
            public static let closeButton = Color(light: "#8E8E93", dark: "#8E8E93")
            public static let shadow = Color(light: "#0000001A", dark: "#0000003D")
        }
        
        // Suggestion items colors
        public enum Suggestion {
            public static let background = Color(light: "#F6F6F6", dark: "#2C2C2E")
            public static let backgroundHighlighted = Color(light: "#ECECEC", dark: "#3A3A3C")
            public static let text = Color(light: "#313330", dark: "#F8F7F9")
            public static let secondaryText = Color(light: "#8E8E93", dark: "#8E8E93")
            public static let border = Color(light: "#E3E4E5", dark: "#444444")
        }
        
        // Result items colors
        public enum Result {
            public static let background = Color(light: "#FFFFFF", dark: "#2C2C2E")
            public static let title = Color(light: "#313330", dark: "#F8F7F9")
            public static let description = Color(light: "#666666", dark: "#E3E4E5")
            public static let border = Color(light: "#E3E4E5", dark: "#444444")
            public static let highlight = Color(light: "#018CDE", dark: "#118AD2")  // Highlighting matching results
        }
        
        // Loading states colors
        public enum Loading {
            public static let shimmer1 = Color(light: "#F6F6F6", dark: "#2C2C2E")
            public static let shimmer2 = Color(light: "#ECECEC", dark: "#3A3A3C")
            public static let spinner = Color(light: "#018CDE", dark: "#118AD2")
        }
        
        // Theme variations
        public enum Theme {
            public enum Blue {
                public static let primary = Color(light: "#018CDE", dark: "#118AD2")
                public static let secondary = Color(light: "#63A4E6", dark: "#63A4E6")
                public static let background = Color(light: "#F3F7FF", dark: "#2C2C2E")
            }
            
            public enum Green {
                public static let primary = Color(light: "#4CAF50", dark: "#4CAF50")
                public static let secondary = Color(light: "#76C375", dark: "#76C375")
                public static let background = Color(light: "#F3FFF3", dark: "#2C2C2E")
            }
            
            public enum Violet {
                public static let primary = Color(light: "#651FFF", dark: "#651FFF")
                public static let secondary = Color(light: "#866EFF", dark: "#866EFF")
                public static let background = Color(light: "#F5F3FF", dark: "#2C2C2E")
            }
            
            public enum Magenta {
                public static let primary = Color(light: "#C2185B", dark: "#C2185B")
                public static let secondary = Color(light: "#D64D7D", dark: "#D64D7D")
                public static let background = Color(light: "#FFF3F7", dark: "#2C2C2E")
            }
        }
    }
}

// Extension to create colors from hex values with light/dark mode support
extension Color {
    init(light: String, dark: String) {
        self.init(UIColor(light: light, dark: dark))
    }
}

// UIColor extension to support light/dark mode colors
extension UIColor {
    convenience init(light: String, dark: String) {
        self.init { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: dark) ?? .black
            } else {
                return UIColor(hex: light) ?? .white
            }
        }
    }
    
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }
        
        if hexString.count != 6 {
            return nil
        }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgb) else {
            return nil
        }
        
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
} 