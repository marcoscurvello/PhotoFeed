//
//  UnsplashEndpoint.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation

nonisolated enum UnsplashEndpoint: Equatable, Sendable {

    case photos(page: Int, perPage: Int)
    case randomPhotos(count: Int)
    case userPhotos(username: String, page: Int, perPage: Int)
    case photoStatistics(id: String)

    var path: String {
        switch self {
        case .photos: "photos"
        case .randomPhotos: "photos/random"
        case .userPhotos(let username, _, _): "users/\(username)/photos"
        case .photoStatistics(let id): "photos/\(id)/statistics"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .photos(let page, let perPage):
            [
                URLQueryItem(name: "page", value: page.description),
                URLQueryItem(name: "per_page", value: perPage.description)
            ]

        case .randomPhotos(let count):
            [
                URLQueryItem(name: "count", value: count.description)
            ]

        case .userPhotos(_, let page, let perPage):
            [
                URLQueryItem(name: "page", value: page.description),
                URLQueryItem(name: "per_page", value: perPage.description)
            ]

        case .photoStatistics:
            [
                URLQueryItem(name: "resolution", value: "days"),
                URLQueryItem(name: "quantity", value: "30")
            ]
        }
    }
}
