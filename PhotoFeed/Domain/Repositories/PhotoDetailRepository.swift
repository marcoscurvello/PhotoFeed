//
//  PhotoDetailRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated protocol PhotoDetailRepository: Sendable {
    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo]
    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics
}
