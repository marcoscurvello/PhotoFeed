//
//  RateLimitSnapshot.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import Foundation

nonisolated struct RateLimitSnapshot: Equatable, Sendable {

    let limit: Int?
    let remaining: Int?
    let retryAfter: Date?
}
