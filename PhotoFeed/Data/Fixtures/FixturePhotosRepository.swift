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

nonisolated struct FixturePhotosRepository: PhotosRepository {

    private let loader: FixtureLoader

    init(loader: FixtureLoader = FixtureLoader()) {
        self.loader = loader
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        guard page == 1 else {
            throw FixturePhotosRepositoryError.unsupportedPage(page)
        }

        let photos: [PhotoDTO] = try loader.load(named: "today_photos")
        return photos.prefix(perPage).map { $0.domainModel() }
    }
}
