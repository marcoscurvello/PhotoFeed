//
//  PhotoPage.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 14/09/2026.
//

import Foundation

nonisolated struct PhotoPage: Sendable {

    let photos: [Photo]
    let page: Int
    let perPage: Int
    let total: Int

    var nextPage: Int? {
        guard !photos.isEmpty, page * perPage < total else {
            return nil
        }

        return page + 1
    }
}
