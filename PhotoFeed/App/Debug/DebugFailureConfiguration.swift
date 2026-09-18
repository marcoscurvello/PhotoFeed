//
//  DebugFailureConfiguration.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

#if DEBUG
import Foundation

nonisolated struct DebugFailureConfiguration: Sendable {

    private enum Constants {
        static let failureTargets = "PHOTOFEED_FAILURE_TARGETS"
        static let failureKind = "PHOTOFEED_FAILURE_KIND"
        static let failureMode = "PHOTOFEED_FAILURE_MODE"
        static let failureDelay = "PHOTOFEED_FAILURE_DELAY"
        static let retryAfter = "PHOTOFEED_RETRY_AFTER"
        static let nextHour = "next-hour"
    }

    private enum RetryDeadline: Sendable {
        case after(TimeInterval)
        case nextHour

        func date(after date: Date) -> Date? {
            switch self {
                case .after(let interval):
                    return date.addingTimeInterval(interval)

                case .nextHour:
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = .gmt
                    return calendar.dateInterval(of: .hour, for: date)?.end
            }
        }
    }

    enum Target: Hashable, Sendable {
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

    let targets: Set<Target>
    let kind: Kind
    let mode: Mode
    let delay: Duration
    private let retryDeadline: RetryDeadline?

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard
            let targets = Self.targets(from: environment[Constants.failureTargets]),
            let kindValue = environment[Constants.failureKind],
            let kind = Kind(rawValue: kindValue),
            let mode = Self.mode(from: environment[Constants.failureMode]),
            let delay = Self.duration(from: environment[Constants.failureDelay])
        else {
            return nil
        }

        let retryDeadline: RetryDeadline?
        if let value = environment[Constants.retryAfter] {
            if value == Constants.nextHour {
                guard kind == .rateLimited else {
                    return nil
                }
                retryDeadline = .nextHour
            } else {
                guard let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 else {
                    return nil
                }
                retryDeadline = .after(seconds)
            }
        } else {
            retryDeadline = nil
        }

        self.targets = targets
        self.kind = kind
        self.mode = mode
        self.delay = delay
        self.retryDeadline = retryDeadline
    }

    func failure(now: Date = .now) -> ResourceLoadFailure {
        let deadline = retryDeadline.flatMap { $0.date(after: now) }

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

    private static func targets(from value: String?) -> Set<Target>? {
        guard let value else {
            return nil
        }

        let values = value.split(separator: ",", omittingEmptySubsequences: false)
        var targets = Set<Target>()

        for value in values {
            let normalizedValue = String(value).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedValue.isEmpty,
                  let target = target(from: normalizedValue) else {
                return nil
            }

            targets.insert(target)
        }

        return targets.isEmpty ? nil : targets
    }

    private static func target(from value: String) -> Target? {
        let todayPagePrefix = "today-page-"

        if value.hasPrefix(todayPagePrefix),
           let page = Int(value.dropFirst(todayPagePrefix.count)), page > 0 {
            return .todayPage(page)
        }

        return switch value {
            case "sponsored": .sponsored
            case "statistics": .statistics
            case "user-photos": .userPhotos
            default: nil
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
