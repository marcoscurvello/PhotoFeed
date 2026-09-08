//
//  UnsplashPhotosRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct UnsplashPhotosRepository: PhotosRepository {

    private let api: UnsplashAPI

    init(api: UnsplashAPI) {
        self.api = api
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        let photos = try await api.photos(page: page, perPage: perPage)
        return photos.map { $0.domainModel() }
    }
}
