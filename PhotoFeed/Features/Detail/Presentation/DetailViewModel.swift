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

    let photo: Photo

    private(set) var userPhotos: [Photo] = []
    private(set) var statistics: PhotoStatistics?

    private(set) var isLoadingUserPhotos = false
    private(set) var isLoadingStatistics = false

    private(set) var userPhotosErrorMessage: String?
    private(set) var statisticsErrorMessage: String?

    private let repository: any PhotoDetailRepository
    private var hasLoaded = false

    init(photo: Photo, repository: any PhotoDetailRepository) {
        self.photo = photo
        self.repository = repository
    }

    func load() async {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true

        async let userPhotos: Void = fetchUserPhotos()
        async let statistics: Void = fetchStatistics()

        _ = await (userPhotos, statistics)
    }

    func retryUserPhotos() async {
        await fetchUserPhotos()
    }

    func retryStatistics() async {
        await fetchStatistics()
    }

    private func fetchUserPhotos() async {
        guard !isLoadingUserPhotos else {
            return
        }

        isLoadingUserPhotos = true
        userPhotosErrorMessage = nil

        defer {
            isLoadingUserPhotos = false
        }

        do {
            userPhotos = try await repository.userPhotos(
                username: photo.user.username,
                page: 1,
                perPage: 10
            )
        } catch is CancellationError {
            return
        } catch {
            userPhotosErrorMessage = error.localizedDescription
        }
    }

    private func fetchStatistics() async {
        guard !isLoadingStatistics else {
            return
        }

        isLoadingStatistics = true
        statisticsErrorMessage = nil

        defer {
            isLoadingStatistics = false
        }

        do {
            statistics = try await repository.statistics(photoID: photo.id)
        } catch is CancellationError {
            return
        } catch {
            statisticsErrorMessage = error.localizedDescription
        }
    }
}
