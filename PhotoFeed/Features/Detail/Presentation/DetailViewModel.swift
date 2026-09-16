//
//  DetailViewModel.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Observation

nonisolated enum DetailResourceState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed

    var loadedValue: Value? {
        guard case .loaded(let value) = self else {
            return nil
        }

        return value
    }
}

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
        await fetchUserPhotos()
    }

    func retryStatistics() async {
        await fetchStatistics()
    }

    private func loadUserPhotosIfNeeded() async {
        guard case .idle = userPhotosState else {
            return
        }

        await fetchUserPhotos()
    }

    private func loadStatisticsIfNeeded() async {
        guard case .idle = statisticsState else {
            return
        }

        await fetchStatistics()
    }

    private func fetchUserPhotos() async {
        guard userPhotosState != .loading else {
            return
        }

        userPhotosState = .loading

        do {
            let userPhotos = try await repository.userPhotos(
                username: photo.user.username,
                page: 1,
                perPage: 10
            )

            guard !Task.isCancelled else {
                userPhotosState = .idle
                return
            }

            userPhotosState = .loaded(userPhotos.filter { $0.id != photo.id })
        } catch {
            userPhotosState = state(for: error)
        }
    }

    private func fetchStatistics() async {
        guard statisticsState != .loading else {
            return
        }

        statisticsState = .loading

        do {
            let statistics = try await repository.statistics(photoID: photo.id)

            guard !Task.isCancelled else {
                statisticsState = .idle
                return
            }

            statisticsState = .loaded(statistics)
        } catch {
            statisticsState = state(for: error)
        }
    }

    private func state<Value: Equatable & Sendable>(for error: Error) -> DetailResourceState<Value> {
        switch HTTPRequestFailureClassification(error) {
        case .cancelled:
            .idle

        case .potentiallyTransient, .nonTransient, .unknown:
            .failed
        }
    }
}
