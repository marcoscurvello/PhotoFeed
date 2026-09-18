//
//  DetailViewModel.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {

    private let photo: Photo
    private let repository: any PhotoDetailRepository

    private(set) var userPhotosState: DetailResourceState<[Photo]> = .idle
    private(set) var statisticsState: DetailResourceState<PhotoStatistics> = .idle

    init(photo: Photo, repository: any PhotoDetailRepository) {
        self.photo = photo
        self.repository = repository
    }

    func load() async {
        async let userPhotos: Void = loadUserPhotosIfNeeded()
        async let statistics: Void = loadStatisticsIfNeeded()

        _ = await (userPhotos, statistics)
    }

    func retryUserPhotos() async {
        guard case .failed(let failure) = userPhotosState, failure.canRetry() else {
            return
        }

        userPhotosState = .retrying(failure)
        await fetchUserPhotos(retrying: failure)
    }

    func retryStatistics() async {
        guard case .failed(let failure) = statisticsState, failure.canRetry() else {
            return
        }

        statisticsState = .retrying(failure)
        await fetchStatistics(retrying: failure)
    }

    var sharedRetryFailure: ResourceLoadFailure? {
        guard let userPhotosFailure = userPhotosState.sharedRetryFailure,
              let statisticsFailure = statisticsState.sharedRetryFailure else {
            return nil
        }

        return failureWithLatestDeadline(userPhotosFailure, statisticsFailure)
    }

    var isRetryingSharedResources: Bool {
        userPhotosState.isRetryingSharedFailure || statisticsState.isRetryingSharedFailure
    }

    func retrySharedResources() async {
        async let userPhotos: Void = retrySharedUserPhotos()
        async let statistics: Void = retrySharedStatistics()

        _ = await (userPhotos, statistics)
    }

    private func loadUserPhotosIfNeeded() async {
        guard case .idle = userPhotosState else {
            return
        }

        await fetchUserPhotos()
    }

    private func retrySharedUserPhotos() async {
        guard case .failed(let failure) = userPhotosState,
              userPhotosState.sharedRetryFailure != nil,
              failure.canRetry() else {
            return
        }

        userPhotosState = .retrying(failure)
        await fetchUserPhotos(retrying: failure)
    }

    private func retrySharedStatistics() async {
        guard case .failed(let failure) = statisticsState,
              statisticsState.sharedRetryFailure != nil,
              failure.canRetry() else {
            return
        }

        statisticsState = .retrying(failure)
        await fetchStatistics(retrying: failure)
    }

    private func loadStatisticsIfNeeded() async {
        guard case .idle = statisticsState else {
            return
        }

        await fetchStatistics()
    }

    private func fetchUserPhotos(retrying failure: ResourceLoadFailure? = nil) async {
        if failure == nil {
            guard userPhotosState != .loading else {
                return
            }

            userPhotosState = .loading
        }

        do {
            let userPhotos = try await repository.userPhotos(
                username: photo.user.username,
                page: 1,
                perPage: 10
            )

            guard !Task.isCancelled else {
                userPhotosState = failure.map(DetailResourceState.failed) ?? .idle
                return
            }

            userPhotosState = .loaded(userPhotos.filter { $0.id != photo.id })
        } catch {
            userPhotosState = state(for: error, retrying: failure)
        }
    }

    private func fetchStatistics(retrying failure: ResourceLoadFailure? = nil) async {
        if failure == nil {
            guard statisticsState != .loading else {
                return
            }

            statisticsState = .loading
        }

        do {
            let statistics = try await repository.statistics(photoID: photo.id)

            guard !Task.isCancelled else {
                statisticsState = failure.map(DetailResourceState.failed) ?? .idle
                return
            }

            statisticsState = .loaded(statistics)
        } catch {
            statisticsState = state(for: error, retrying: failure)
        }
    }

    private func state<Value: Equatable & Sendable>(
        for error: Error,
        retrying failure: ResourceLoadFailure?
    ) -> DetailResourceState<Value> {

        guard !(error is CancellationError || (error as? URLError)?.code == .cancelled) else {
            return failure.map(DetailResourceState.failed) ?? .idle
        }

        return .failed((error as? ResourceLoadFailure) ?? .unknown)
    }

    private func failureWithLatestDeadline(
        _ first: ResourceLoadFailure,
        _ second: ResourceLoadFailure
    ) -> ResourceLoadFailure {

        switch (first.retryEligibility, second.retryEligibility) {
        case let (.after(firstDeadline), .after(secondDeadline)):
            firstDeadline >= secondDeadline ? first : second
        case (.after, _):
            first
        case (_, .after):
            second
        case (.immediate, .immediate):
            first
        case (.unavailable, _), (_, .unavailable):
            preconditionFailure("Shared retry failures must be retryable.")
        }
    }
}
