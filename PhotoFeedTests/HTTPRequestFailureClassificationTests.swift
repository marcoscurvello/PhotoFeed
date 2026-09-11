//
//  HTTPRequestFailureClassificationTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("HTTP request failure classification")
struct HTTPRequestFailureClassificationTests {

    @Test("Cancellation errors are classified as cancelled")
    func classifiesCancellation() {
        #expect(matchesCancellation(HTTPRequestFailureClassification(CancellationError())))
        #expect(matchesCancellation(HTTPRequestFailureClassification(URLError(.cancelled))))
    }

    @Test("Rate limits and server failures remain transient with their deadline")
    func classifiesTransientHTTPFailures() throws {
        let deadline = Date(timeIntervalSince1970: 123)

        for statusCode in [408, 429, 500, 503, 599] {
            let classification = HTTPRequestFailureClassification(
                HTTPClientError.unacceptableStatusCode(
                    statusCode,
                    Data(),
                    retryAfter: deadline
                )
            )

            guard case .potentiallyTransient(let retryAfter) = classification else {
                Issue.record("Expected status \(statusCode) to be transient")
                continue
            }
            #expect(retryAfter == deadline)
        }
    }

    @Test("Permanent HTTP failures are non-transient")
    func classifiesPermanentHTTPFailures() {
        for statusCode in [200, 400, 401, 404] {
            let classification = HTTPRequestFailureClassification(
                HTTPClientError.unacceptableStatusCode(statusCode, Data())
            )
            #expect(matchesNonTransient(classification))
        }

        #expect(matchesNonTransient(HTTPRequestFailureClassification(HTTPClientError.invalidURL)))
        #expect(matchesNonTransient(HTTPRequestFailureClassification(HTTPClientError.invalidResponse)))
    }

    @Test("Transient URL errors are classified as transient")
    func classifiesTransientURLErrors() {
        let transientCodes: [URLError.Code] = [
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .dataNotAllowed,
            .internationalRoamingOff,
            .callIsActive
        ]

        for code in transientCodes {
            guard case .potentiallyTransient(let retryAfter) = HTTPRequestFailureClassification(URLError(code)) else {
                Issue.record("Expected URL error \(code) to be transient")
                continue
            }
            #expect(retryAfter == nil)
        }
    }

    @Test("Permanent URL errors, decoding errors, and unknown errors are distinguished")
    func classifiesOtherErrors() {
        #expect(matchesNonTransient(HTTPRequestFailureClassification(URLError(.badURL))))

        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "invalid")
        )
        #expect(matchesNonTransient(HTTPRequestFailureClassification(decodingError)))
        #expect(matchesUnknown(HTTPRequestFailureClassification(TestError.example)))
    }

    private func matchesCancellation(_ classification: HTTPRequestFailureClassification) -> Bool {
        guard case .cancelled = classification else { return false }
        return true
    }

    private func matchesNonTransient(_ classification: HTTPRequestFailureClassification) -> Bool {
        guard case .nonTransient = classification else { return false }
        return true
    }

    private func matchesUnknown(_ classification: HTTPRequestFailureClassification) -> Bool {
        guard case .unknown = classification else { return false }
        return true
    }

    private enum TestError: Error {
        case example
    }
}
