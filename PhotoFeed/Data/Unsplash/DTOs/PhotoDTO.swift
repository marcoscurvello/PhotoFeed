//
//  PhotoDTO.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct PhotoDTO: Decodable, Sendable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let blurHash: String?
    let description: String?
    let altDescription: String?
    let urls: PhotoURLsDTO
    let links: PhotoLinksDTO
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
        case id
        case width
        case height
        case color
        case blurHash = "blur_hash"
        case description
        case altDescription = "alt_description"
        case urls
        case links
        case user
    }
}

nonisolated struct PhotoURLsDTO: Decodable, Sendable {
    let raw: URL
    let full: URL
    let regular: URL
    let small: URL
    let thumb: URL
}

nonisolated struct PhotoLinksDTO: Decodable, Sendable {
    let html: URL
    let downloadLocation: URL?

    enum CodingKeys: String, CodingKey {
        case html
        case downloadLocation = "download_location"
    }
}
