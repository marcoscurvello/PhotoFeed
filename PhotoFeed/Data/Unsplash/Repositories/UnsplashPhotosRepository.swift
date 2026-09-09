//
//  UnsplashPhotosRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct UnsplashPhotosRepository: PhotosRepository, PhotoDetailRepository {

    private let api: UnsplashAPI

    init(api: UnsplashAPI) {
        self.api = api
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        let photos = try await api.photos(page: page, perPage: perPage)
        return photos.map(\.domainModel)
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        let photos = try await api.sponsoredPhotos(count: count)
        return photos.map(\.domainModel)
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        let photos = try await api.userPhotos(username: username, page: page, perPage: perPage)
        return photos.map(\.domainModel)
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        let statistics = try await api.statistics(photoID: photoID.rawValue)
        return statistics.domainModel
    }
}
