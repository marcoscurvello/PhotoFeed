//
//  FixturePhotosRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum FixturePhotosRepositoryError: Error, Equatable {
    case invalidPage(Int)
    case invalidPageSize(Int)
    case unsupportedPage(Int)
}

nonisolated struct FixturePhotosRepository: PhotosRepository, PhotoDetailRepository {

    private enum Constants {
        static let todayPhotos: String = "today_photos"
        static let sponsoredPhotos: String = "sponsored_photos"
        static let userPhotos: String = "user_photos"
        static let photoStatistics: String = "photo_statistics"
    }

    private let loader: FixtureLoader
    private let sponsoredPhotoSequence = FixtureSponsoredPhotoSequence()

    init(loader: FixtureLoader = FixtureLoader()) {
        self.loader = loader
    }

    func photos(page: Int, perPage: Int) async throws -> PhotoPage {
        guard page > 0 else {
            throw FixturePhotosRepositoryError.invalidPage(page)
        }

        guard perPage > 0 else {
            throw FixturePhotosRepositoryError.invalidPageSize(perPage)
        }

        let photos: [PhotoDTO] = try loader.load(named: Constants.todayPhotos)
        let domainPhotos = photos.map(\.domainModel)
        let startIndex = (page - 1) * perPage
        let pagePhotos: [Photo]

        if startIndex < domainPhotos.count {
            let endIndex = min(startIndex + perPage, domainPhotos.count)
            pagePhotos = Array(domainPhotos[startIndex..<endIndex])
        } else {
            pagePhotos = []
        }

        return PhotoPage(
            photos: pagePhotos,
            page: page,
            perPage: perPage,
            total: domainPhotos.count
        )
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        let photos: [PhotoDTO] = try loader.load(named: Constants.sponsoredPhotos)
        return await sponsoredPhotoSequence.next(
            from: photos.map(\.domainModel),
            count: count
        )
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        guard page == 1 else {
            throw FixturePhotosRepositoryError.unsupportedPage(page)
        }

        let photos: [PhotoDTO] = try loader.load(named: Constants.userPhotos)
        return photos.prefix(perPage).map(\.domainModel)
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        let statistics: PhotoStatisticsDTO = try loader.load(named: Constants.photoStatistics)
        return statistics.domainModel
    }
}
