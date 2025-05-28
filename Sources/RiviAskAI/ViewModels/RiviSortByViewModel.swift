import SwiftUI

/// ViewModel that manages the state and logic for the RiviSortByButton
public class RiviSortByViewModel: ObservableObject {
    /// Whether the popup is currently visible
    @Published public var isPopupVisible = false
    
    /// Available sort options
    public let options: [String]
    
    /// Closure called when a selection is made
    private let onSelection: ((String) -> Void)?
    
    /// Initialize the view model
    /// - Parameters:
    ///   - options: Available sorting options
    ///   - onSelection: Closure called when a selection is made
    public init(
        options: [String],
        onSelection: ((String) -> Void)? = nil
    ) {
        self.options = options
        self.onSelection = onSelection
        RiviAskAILogger.log("RiviSortByViewModel initialized with \(options.count) options", level: .debug)
    }
    
    /// Toggle the visibility of the popup
    public func togglePopup() {
        isPopupVisible.toggle()
        RiviAskAILogger.log("Sort options popup visibility toggled to: \(isPopupVisible)", level: .debug)
    }
    
    /// Handle selection of a sort option
    /// - Parameter option: The selected option
    public func selectOption(_ option: String) {
        RiviAskAILogger.log("Sort option selected: \(option)", level: .info)
        onSelection?(option)
    }
    
    deinit {
        RiviAskAILogger.log("RiviSortByViewModel deinitializing", level: .debug)
    }
} 