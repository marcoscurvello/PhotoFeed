//
//  HTTPRequestFailureClassification.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation

nonisolated enum HTTPRequestFailureClassification: Sendable {

    case cancelled
    case potentiallyTransient(retryAfter: Date?)
    case nonTransient
    case unknown

    init(_ error: Error) {
        switch error {
        case is CancellationError:
            self = .cancelled

        case let httpError as HTTPClientError:
            switch httpError {
            case .unacceptableStatusCode(let statusCode, _, let retryAfter):
                if statusCode == 408 || statusCode == 429 || (500..<600).contains(statusCode) {
                    self = .potentiallyTransient(retryAfter: retryAfter)
                } else {
                    self = .nonTransient
                }

            case .invalidURL, .invalidResponse:
                self = .nonTransient
            }

        case let urlError as URLError:
            switch urlError.code {
            case .cancelled:
                self = .cancelled

            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .dataNotAllowed,
                 .internationalRoamingOff,
                 .callIsActive:
                self = .potentiallyTransient(retryAfter: nil)

            default:
                self = .nonTransient
            }

        case is DecodingError:
            self = .nonTransient

        default:
            self = .unknown
        }
    }
}
