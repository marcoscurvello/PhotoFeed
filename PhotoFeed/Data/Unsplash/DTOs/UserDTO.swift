//
//  UserDTO.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct UserDTO: Decodable, Sendable {
    let id: String
    let username: String
    let name: String?
    let profileImage: ProfileImageDTO
    let links: UserLinksDTO

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case profileImage = "profile_image"
        case links
    }
}

nonisolated struct ProfileImageDTO: Decodable, Sendable {
    let small: URL
    let medium: URL
    let large: URL
}

nonisolated struct UserLinksDTO: Decodable, Sendable {
    let html: URL
    let photos: URL
}
