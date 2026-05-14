//
//  RiviAskAI
//
//  Created by Shubham Nanda on 02/02/26.
//

import Foundation

// MARK: - Disconnect Reason
public enum DisconnectReason {
    case timeout
    case serverClosed
    case cancelled
    case maxRetriesExceeded
    case networkError(message: String?)
    case unknown(cause: Error)

    /// Determines if the client should attempt to retry based on the error type
    public var isRecoverable: Bool {
        switch self {
        case .timeout, .networkError:
            return true
        case .serverClosed, .cancelled, .maxRetriesExceeded, .unknown:
            return false
        }
    }
}

// MARK: - Connection State
public enum SSEConnectionState {
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int, nextRetryIn: TimeInterval)
    case disconnected(reason: DisconnectReason)

    // Helper Computed Properties
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}
