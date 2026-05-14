//
//  File.swift
//  RiviAskAI
//
//  Created by Shubham Nanda on 02/02/26.
//

import Foundation
/// Configuration for connection behavior (SSE).
/// Controls timeouts and retry policies for Server-Sent Events streams.
public struct SSEConfig {
    public let connectTimeout: TimeInterval
    public let maxReconnectAttempts: Int
    public let initialReconnectDelay: TimeInterval
    public let maxReconnectDelay: TimeInterval
    public let reconnectBackoffMultiplier: Double

    public init(
        connectTimeout: TimeInterval = 30.0,
        maxReconnectAttempts: Int = 5,
        initialReconnectDelay: TimeInterval = 1.0,
        maxReconnectDelay: TimeInterval = 30.0,
        reconnectBackoffMultiplier: Double = 2.0
    ) {
        self.connectTimeout = connectTimeout
        self.maxReconnectAttempts = maxReconnectAttempts
        self.initialReconnectDelay = initialReconnectDelay
        self.maxReconnectDelay = maxReconnectDelay
        self.reconnectBackoffMultiplier = reconnectBackoffMultiplier
    }
    
    // Presets
    public static let `default` = SSEConfig()
    
    public static let aggressive = SSEConfig(
        connectTimeout: 15.0,
        maxReconnectAttempts: 10,
        initialReconnectDelay: 0.5,
        maxReconnectDelay: 10.0
    )
    
    public static let conservative = SSEConfig(
        connectTimeout: 60.0,
        maxReconnectAttempts: 3,
        initialReconnectDelay: 2.0,
        maxReconnectDelay: 60.0
    )
}
