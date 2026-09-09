//
//  FixturePhotosRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum FixturePhotosRepositoryError: Error, Equatable {
    case unsupportedPage(Int)
}

nonisolated struct FixturePhotosRepository: PhotosRepository, PhotoDetailRepository {

    private let loader: FixtureLoader

    init(loader: FixtureLoader = FixtureLoader()) {
        self.loader = loader
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        guard page == 1 else {
            throw FixturePhotosRepositoryError.unsupportedPage(page)
        }

        let photos: [PhotoDTO] = try loader.load(named: "today_photos")
        return photos.prefix(perPage).map(\.domainModel)
    }
    
    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        let photos: [PhotoDTO] = try loader.load(named: "sponsored_photos")
        return photos.prefix(count).map(\.domainModel)
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        guard page == 1 else {
            throw FixturePhotosRepositoryError.unsupportedPage(page)
        }

        let photos: [PhotoDTO] = try loader.load(named: "user_photos")
        return photos.prefix(perPage).map(\.domainModel)
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        let statistics: PhotoStatisticsDTO = try loader.load(named: "photo_statistics")
        return statistics.domainModel
    }
}
