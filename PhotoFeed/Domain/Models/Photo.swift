//
//  Photo.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct Photo: Identifiable, Hashable, Sendable {

    nonisolated struct ID: RawRepresentable, Hashable, Sendable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    nonisolated struct ImageURLs: Hashable, Sendable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumbnail: URL
    }

    let id: ID
    let width: Int
    let height: Int
    let colorHex: String?
    let blurHash: String?
    let description: String?
    let imageURLs: ImageURLs
    let user: User
    let webpageURL: URL

    init(
        id: ID,
        width: Int,
        height: Int,
        colorHex: String?,
        blurHash: String? = nil,
        description: String?,
        imageURLs: ImageURLs,
        user: User,
        webpageURL: URL
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.colorHex = colorHex
        self.blurHash = blurHash
        self.description = description
        self.imageURLs = imageURLs
        self.user = user
        self.webpageURL = webpageURL
    }

    var aspectRatio: Double {
        guard height > 0 else {
            return 1
        }

        return Double(width) / Double(height)
    }
}
