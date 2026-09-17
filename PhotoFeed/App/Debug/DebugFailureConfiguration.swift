//
//  DebugFailureConfiguration.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

#if DEBUG
import Foundation

nonisolated struct DebugFailureConfiguration: Sendable {

    enum Target: Equatable, Sendable {
        case todayPage(Int)
        case sponsored
        case statistics
        case userPhotos
    }

    enum Kind: String, Equatable, Sendable {
        case offline
        case timedOut = "timed-out"
        case rateLimited = "rate-limited"
        case serviceUnavailable = "service-unavailable"
        case accessDenied = "access-denied"
        case notFound = "not-found"
        case invalidResponse = "invalid-response"
        case unknown
    }

    enum Mode: String, Equatable, Sendable {
        case once
        case always
    }

    let target: Target
    let kind: Kind
    let mode: Mode
    let delay: Duration
    let retryAfter: TimeInterval?

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard
            let target = Self.target(from: environment["PHOTOFEED_FAILURE_TARGET"]),
            let kindValue = environment["PHOTOFEED_FAILURE_KIND"],
            let kind = Kind(rawValue: kindValue),
            let mode = Self.mode(from: environment["PHOTOFEED_FAILURE_MODE"]),
            let delay = Self.duration(from: environment["PHOTOFEED_FAILURE_DELAY"])
                else {
            return nil
        }

        let retryAfter: TimeInterval?
        if let value = environment["PHOTOFEED_RETRY_AFTER"] {
            guard let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 else {
                return nil
            }
            retryAfter = seconds
        } else {
            retryAfter = nil
        }

        self.target = target
        self.kind = kind
        self.mode = mode
        self.delay = delay
        self.retryAfter = retryAfter
    }

    func failure(now: Date = .now) -> ResourceLoadFailure {
        let deadline = retryAfter.map(now.addingTimeInterval)

        return switch kind {
            case .offline:
                    .offline
            case .timedOut:
                    .timedOut
            case .rateLimited:
                    .rateLimited(.init(limit: 50, remaining: 0, retryAfter: deadline))
            case .serviceUnavailable:
                    .serviceUnavailable(retryAfter: deadline)
            case .accessDenied:
                    .accessDenied
            case .notFound:
                    .notFound
            case .invalidResponse:
                    .invalidResponse
            case .unknown:
                    .unknown
        }
    }

    private static func target(from value: String?) -> Target? {
        guard let value else {
            return nil
        }

        let todayPagePrefix = "today-page-"
        if value.hasPrefix(todayPagePrefix),
           let page = Int(value.dropFirst(todayPagePrefix.count)),
           page > 0 {
            return .todayPage(page)
        }

        return switch value {
            case "sponsored":
                    .sponsored
            case "statistics":
                    .statistics
            case "user-photos":
                    .userPhotos
            default:
                nil
        }
    }

    private static func mode(from value: String?) -> Mode? {
        guard let value else {
            return .always
        }

        return Mode(rawValue: value)
    }

    private static func duration(from value: String?) -> Duration? {
        guard let value else {
            return .zero
        }

        guard let seconds = Double(value),
              seconds.isFinite,
              seconds >= 0,
              seconds <= Double(Int64.max) / 1_000 else {
            return nil
        }

        return .milliseconds(Int64((seconds * 1_000).rounded()))
    }

}
#endif
