//
//  PhotosRepository.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated protocol PhotosRepository: Sendable {
    func photos(page: Int, perPage: Int) async throws -> [Photo]
}
