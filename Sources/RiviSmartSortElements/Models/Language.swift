import Foundation
import SwiftUI

/// Enum representing supported languages
public enum Language: String {
    case english = "en"
    case arabic = "ar"
    
    public var layoutDirection: LayoutDirection {
        switch self {
        case .english:
                .leftToRight
        case .arabic:
                .rightToLeft
        }
    }
}
