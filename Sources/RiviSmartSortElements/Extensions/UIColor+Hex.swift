import UIKit

/// Extension for creating UIColors from hex strings and converting UIColors to hex format
public extension UIColor {
    /// Creates a UIColor from a hex string (RGB, RGBA, RRGGBB, or RRGGBBAA format)
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        // Remove '#' prefix if present
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        
        // Convert to uppercase for consistency
        hexString = hexString.uppercased()
        
        // Validate hex string length
        guard [3, 4, 6, 8].contains(hexString.count) else {
            return nil
        }
        
        // Convert 3/4 character hex to 6/8 character format
        if hexString.count < 6 {
            hexString = hexString.map { "\($0)\($0)" }.joined()
        }
        
        // Add full opacity if no alpha provided
        if hexString.count == 6 {
            hexString += "FF"
        }
        
        // Convert hex string to integer
        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
            return nil
        }
        
        // Extract color components
        r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
        g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
        b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
        a = CGFloat(rgbValue & 0x000000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    /// Converts UIColor to hex string with optional alpha and hash prefix
    func toHex(includeAlpha: Bool = true, includeHashPrefix: Bool = true) -> String {
        guard let components = cgColor.components else { return "" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : Float(1.0)
        
        let prefix = includeHashPrefix ? "#" : ""
        
        if includeAlpha {
            return String(format: "\(prefix)%02lX%02lX%02lX%02lX",
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255),
                          lroundf(a * 255))
        } else {
            return String(format: "\(prefix)%02lX%02lX%02lX",
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255))
        }
    }
}
