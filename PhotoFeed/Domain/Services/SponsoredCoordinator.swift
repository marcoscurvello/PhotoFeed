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
        case inactive
        case waitingForOpportunity
        case enabled
        case suspended
    }

    private let repository: any PhotosRepository
    private let configuration: SponsoredCoordinatorConfiguration
    private let isEligible: @MainActor (Photo) -> Bool
    private let onCandidatesAvailable: @MainActor () -> Void

    private var candidates: [Photo] = []
    private var worker: Task<Void, Never>?

    private var state: State = .inactive
    private var latestCoverage = 0
    private var requiredCoverage: Int
    private var requestsRemainingInEpisode: Int?
    private var retryAfter: Date?
    private var consecutiveUnsuccessfulEpisodes = 0

    init(
        repository: any PhotosRepository,
        configuration: SponsoredCoordinatorConfiguration = .init(),
        isEligible: @escaping @MainActor (Photo) -> Bool,
        onCandidatesAvailable: @escaping @MainActor () -> Void
    ) {
        self.repository = repository
        self.configuration = configuration
        self.requiredCoverage = configuration.targetCoverage
        self.isEligible = isEligible
        self.onCandidatesAvailable = onCandidatesAvailable
    }

    var candidateCount: Int { candidates.count }
    var maximumCoverage: Int { configuration.targetCoverage }

    func activate() {
        guard state == .inactive else {
            return
        }

        state = .waitingForOpportunity
    }

    func deactivate() {
        if state != .suspended {
            state = .inactive
        }

        worker?.cancel()
    }

    func reconcile(coverage: Int, targetCoverage: Int?, hasSupplyOpportunity: Bool) {
        latestCoverage = coverage
        requiredCoverage = min(configuration.targetCoverage, targetCoverage ?? configuration.targetCoverage)

        switch state {
        case .waitingForOpportunity, .enabled:
            state = hasSupplyOpportunity ? .enabled : .waitingForOpportunity

        case .inactive, .suspended:
            break
        }

        if state != .enabled {
            worker?.cancel()
        }

        guard state != .suspended else { return }
        if requiredCoverage > 0, coverage >= requiredCoverage {
            recoverAfterMeetingTarget()
            return
        }

        startWorkerIfNeeded()
    }

    func takeNextCandidate() -> Photo? {
        guard !candidates.isEmpty else { return nil }
        return candidates.removeFirst()
    }

    func removeCandidate(withID id: Photo.ID) {
        candidates.removeAll { $0.id == id }
    }

    private var hasRemainingDemand: Bool {
        state == .enabled
        && latestCoverage < requiredCoverage
    }

    private var shouldRunWorker: Bool {
        hasRemainingDemand
        && (latestCoverage <= configuration.lowWatermark || requestsRemainingInEpisode != nil || retryAfter != nil)
    }

    private func startWorkerIfNeeded() {
        guard worker == nil, shouldRunWorker else {
            return
        }

        worker = Task { [weak self] in
            await self?.runWorker()
        }
    }

    private func runWorker() async {
        defer {
            worker = nil
            startWorkerIfNeeded()
        }

        while let retryAfter, retryAfter > Date() {
            do {
                try await Task.sleep(for: .seconds(min(retryAfter.timeIntervalSinceNow, 3_600)))
            } catch {
                return
            }
        }

        guard !Task.isCancelled, shouldRunWorker else {
            return
        }

        if let retryAfter, retryAfter <= Date() {
            self.retryAfter = nil
            requestsRemainingInEpisode = configuration.maximumRequestsPerEpisode
        }
        if requestsRemainingInEpisode == nil {
            requestsRemainingInEpisode = configuration.maximumRequestsPerEpisode
        }

        while !Task.isCancelled, hasRemainingDemand,
              let requestsRemainingInEpisode, requestsRemainingInEpisode > 0 {
            self.requestsRemainingInEpisode = requestsRemainingInEpisode - 1

            do {
                let photos = try await repository.sponsoredPhotos(count: configuration.requestBatchSize)
                guard !Task.isCancelled else { return }

                appendEligibleCandidates(from: photos)
                onCandidatesAvailable()

                if latestCoverage >= requiredCoverage {
                    recoverAfterMeetingTarget()
                    return
                }
            } catch {
                guard !Task.isCancelled else { return }
                handle(error)
                return
            }
        }

        guard !Task.isCancelled, hasRemainingDemand else { return }
        startCooldown(serverRetryAfter: nil)
    }

    private func appendEligibleCandidates(from photos: [Photo]) {
        let availableCapacity = max(requiredCoverage - latestCoverage, 0)
        var acceptedCount = 0

        for photo in photos {
            guard acceptedCount < availableCapacity,
                  !candidates.contains(where: { $0.id == photo.id }),
                  isEligible(photo) else {
                continue
            }
            candidates.append(photo)
            acceptedCount += 1
        }
    }

    private func recoverAfterMeetingTarget() {
        requestsRemainingInEpisode = nil
        consecutiveUnsuccessfulEpisodes = 0

        if let retryAfter, retryAfter <= Date() {
            self.retryAfter = nil
        }
    }

    private func handle(_ error: Error) {
        switch HTTPRequestFailureClassification(error) {
        case .cancelled:
            return

        case .potentiallyTransient(let serverRetryAfter):
            startCooldown(serverRetryAfter: serverRetryAfter)

        case .nonTransient:
            state = .suspended

        case .unknown:
            startCooldown(serverRetryAfter: nil)
        }
    }

    private func startCooldown(serverRetryAfter: Date?) {
        requestsRemainingInEpisode = nil
        consecutiveUnsuccessfulEpisodes += 1

        let exponent = min(consecutiveUnsuccessfulEpisodes - 1, 4)
        let localDelay = min(30 * pow(2, Double(exponent)) * Double.random(in: 0.85...1.15), 300)
        let localRetryAfter = Date().addingTimeInterval(localDelay)

        retryAfter = [localRetryAfter, serverRetryAfter].compactMap { $0 }.max()
    }
}
