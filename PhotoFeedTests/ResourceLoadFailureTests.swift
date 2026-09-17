//
//  ResourceLoadFailureTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Resource load failures")
struct ResourceLoadFailureTests {

    @Test("A rate limit without a server deadline is immediately retryable")
    func rateLimitWithoutDeadlineIsImmediatelyRetryable() {
        #expect(ResourceLoadFailure.rateLimited(.init(limit: 50, remaining: 0, retryAfter: nil)).canRetry())
    }

    @Test("Server and rate-limit deadlines defer retry eligibility until they expire")
    func serverAndRateLimitDeadlinesDeferRetryEligibility() {
        let deadline = Date(timeIntervalSince1970: 123)

        #expect(
            ResourceLoadFailure.serviceUnavailable(retryAfter: deadline).retryEligibility
                == .after(deadline)
        )
        #expect(
            ResourceLoadFailure.rateLimited(.init(limit: 50, remaining: 0, retryAfter: nil)).retryEligibility
                == .immediate
        )

        let delayedFailure = ResourceLoadFailure.rateLimited(
            .init(limit: 50, remaining: 0, retryAfter: deadline)
        )
        #expect(!delayedFailure.canRetry(at: deadline.addingTimeInterval(-1)))
        #expect(delayedFailure.canRetry(at: deadline))
    }

    @Test("Access and not-found failures are not retryable")
    func accessAndNotFoundFailuresAreNotRetryable() {
        #expect(ResourceLoadFailure.accessDenied.retryEligibility == .unavailable)
        #expect(ResourceLoadFailure.notFound.retryEligibility == .unavailable)
    }

    @Test("Offline and timeout failures are immediately retryable")
    func offlineAndTimeoutFailuresAreImmediatelyRetryable() {
        #expect(ResourceLoadFailure.timedOut.retryEligibility == .immediate)
        #expect(ResourceLoadFailure.offline.retryEligibility == .immediate)
    }

    @Test("Invalid responses are unavailable while unknown failures remain retryable")
    func invalidResponsesAndUnknownFailuresHaveDistinctRetryEligibility() {
        #expect(ResourceLoadFailure.invalidResponse.retryEligibility == .unavailable)
        #expect(ResourceLoadFailure.unknown.retryEligibility == .immediate)
    }

}
