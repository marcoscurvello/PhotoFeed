//
//  ResourceLoadFailure.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import Foundation

nonisolated enum ResourceLoadFailure: Error, Equatable, Sendable {

    enum RetryEligibility: Equatable, Sendable {
        case immediate
        case after(Date)
        case unavailable
    }

    case offline
    case timedOut
    case rateLimited(RateLimitSnapshot)
    case serviceUnavailable(retryAfter: Date?)
    case accessDenied
    case notFound
    case invalidResponse
    case unknown

    var retryEligibility: RetryEligibility {
        switch self {
        case .offline, .timedOut, .unknown:
            .immediate

        case .rateLimited(let snapshot):
            snapshot.retryAfter.map(RetryEligibility.after) ?? .immediate

        case .serviceUnavailable(let retryAfter):
            retryAfter.map(RetryEligibility.after) ?? .immediate

        case .accessDenied, .notFound, .invalidResponse:
            .unavailable
        }
    }

    func canRetry(at date: Date = .now) -> Bool {
        switch retryEligibility {
        case .immediate:
            true
        case .after(let deadline):
            deadline <= date
        case .unavailable:
            false
        }
    }
}
