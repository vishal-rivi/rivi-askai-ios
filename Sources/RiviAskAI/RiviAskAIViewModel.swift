import SwiftUI

/// ViewModel that manages the state and logic for the RiviAskAIButton
public class RiviAskAIViewModel: ObservableObject {
    /// Whether the popup is currently visible
    @Published public var isPopupVisible = false
    
    /// The current text input
    @Published public var inputText = ""
    
    /// Closure called when the user taps the "Improve Results" button
    public let onImproveResults: () -> Void
    
    /// Initialize the view model
    /// - Parameters:
    ///   - onImproveResults: Closure called when the user taps "Improve Results"
    public init(onImproveResults: @escaping () -> Void) {
        self.onImproveResults = onImproveResults
    }
    
    /// Toggle the popup visibility
    public func togglePopup() {
        isPopupVisible.toggle()
    }
    
    /// Set the input text to a selected suggestion
    /// - Parameter suggestion: The suggestion to use
    public func selectSuggestion(_ suggestion: String) {
        inputText = suggestion
    }
    
    /// Call the improve results closure and close the popup
    public func improveResults() {
        onImproveResults()
        isPopupVisible = false
    }
} 
