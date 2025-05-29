import Foundation
import SwiftUI

/// Event type for SSE responses
public enum RiviAskAIEvent {
    /// Received data from the SSE connection
    case data(String)
    /// Error occurred during the SSE connection
    case error(Error)
    /// Connection closed or disconnected
    case disconnected
    /// Filter search API call completed
    case filterSearchCompleted
    /// Chips extracted from the SSE data
    case chipsExtracted(Set<String>)
}
