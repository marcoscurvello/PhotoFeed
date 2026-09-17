//
//  SponsoredCoordinator.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation

@MainActor
final class SponsoredCoordinator {

    private enum State: Equatable {
        case idle
        case loading
        case suspended
    }

    private let repository: any PhotosRepository
    private let configuration: SponsoredCoordinatorConfiguration

    private var state: State = .idle
    private var retryAfter: Date?
    private var consecutiveUnsuccessfulEpisodes = 0

    init(
        repository: any PhotosRepository,
        configuration: SponsoredCoordinatorConfiguration = .init()
    ) {
        self.repository = repository
        self.configuration = configuration
    }

    func loadCandidates(count: Int, excluding excludedIDs: Set<Photo.ID>) async -> [Photo] {
        guard state == .idle, count > 0 else {
            return []
        }

        if let retryAfter {
            guard retryAfter <= Date() else {
                return []
            }

            self.retryAfter = nil
        }

        state = .loading

        defer {
            if state == .loading { state = .idle }
        }

        var candidates: [Photo] = []
        var knownIDs = excludedIDs

        for _ in 0..<configuration.maximumRequestsPerEpisode {
            guard !Task.isCancelled, candidates.count < count else {
                break
            }

            do {
                let remainingCount = count - candidates.count
                let requestCount = min(configuration.requestBatchSize, remainingCount)
                let photos = try await repository.sponsoredPhotos(count: requestCount)

                guard !Task.isCancelled else {
                    return candidates
                }

                for photo in photos {
                    guard knownIDs.insert(photo.id).inserted else {
                        continue
                    }

                    candidates.append(photo)

                    guard candidates.count < count else {
                        break
                    }
                }
            } catch {
                guard !Task.isCancelled else {
                    return candidates
                }

                handle(error)
                return candidates
            }
        }

        guard !Task.isCancelled else {
            return candidates
        }

        if candidates.count >= count {
            recoverAfterSuccessfulEpisode()
        } else {
            startCooldown(serverRetryAfter: nil)
        }

        return candidates
    }

    private func recoverAfterSuccessfulEpisode() {
        retryAfter = nil
        consecutiveUnsuccessfulEpisodes = 0
    }

    private func handle(_ error: Error) {
        guard !(error is CancellationError) else {
            return
        }

        let failure = (error as? ResourceLoadFailure) ?? .unknown

        switch failure.retryEligibility {
        case .immediate:
            startCooldown(serverRetryAfter: nil)

        case .after(let serverRetryAfter):
            startCooldown(serverRetryAfter: serverRetryAfter)

        case .unavailable:
            state = .suspended
        }
    }

    private func startCooldown(serverRetryAfter: Date?) {
        consecutiveUnsuccessfulEpisodes += 1

        let exponent = min(consecutiveUnsuccessfulEpisodes - 1, 4)
        let localDelay = min(
            30 * pow(2, Double(exponent)),
            300
        )

        let localRetryAfter = Date().addingTimeInterval(localDelay)

        retryAfter = [
            localRetryAfter,
            serverRetryAfter
        ]
        .compactMap { $0 }
        .max()
    }
}
