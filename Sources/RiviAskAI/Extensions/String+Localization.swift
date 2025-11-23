import Foundation

/// Extension for String localization based on the configured language
extension String {
    /// Get localized string based on the current language configuration
    /// - Returns: Localized string
    func localized() -> String {
        let language = RiviAskAIConfiguration.shared.language
        let languageCode = language.rawValue
        
        // Try to get the localized string from the bundle
        if let bundle = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: bundle) {
            let localizedString = NSLocalizedString(self, bundle: langBundle, comment: "")
            if localizedString != self {
                return localizedString
            }
        }
        
        // Fallback to default bundle
        return NSLocalizedString(self, bundle: .module, comment: "")
    }
}
