//
//  FaultInjectingPhotoRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

#if DEBUG
import Foundation

actor FaultInjectingPhotoRepository<Base>: PhotosRepository, PhotoDetailRepository
where Base: PhotosRepository & PhotoDetailRepository {

    private let base: Base
    private let configuration: DebugFailureConfiguration
    private var hasInjectedFailure = false

    init(base: Base, configuration: DebugFailureConfiguration) {
        self.base = base
        self.configuration = configuration
    }

    func photos(page: Int, perPage: Int) async throws -> PhotoPage {
        try await intercept(.todayPage(page))
        return try await base.photos(page: page, perPage: perPage)
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        try await intercept(.sponsored)
        return try await base.sponsoredPhotos(count: count)
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        try await intercept(.userPhotos)
        return try await base.userPhotos(username: username, page: page, perPage: perPage)
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        try await intercept(.statistics)
        return try await base.statistics(photoID: photoID)
    }

    private func intercept(_ target: DebugFailureConfiguration.Target) async throws {
        guard target == configuration.target else {
            return
        }

        if configuration.delay > .zero {
            try await Task.sleep(for: configuration.delay)
        }

        switch configuration.mode {
        case .always:
            throw configuration.failure()

        case .once:
            guard !hasInjectedFailure else {
                return
            }

            hasInjectedFailure = true
            throw configuration.failure()
        }
    }
}
#endif
