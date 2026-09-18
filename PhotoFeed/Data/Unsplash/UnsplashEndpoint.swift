//
//  UnsplashEndpoint.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation

nonisolated private enum UnsplashQueryName: String {
    case page
    case perPage = "per_page"
    case count
    case resolution
    case quantity
}

nonisolated private extension HTTPQueryParameter {

    static func page(_ value: Int) -> Self {
        Self(name: UnsplashQueryName.page, value: String(value))
    }

    static func perPage(_ value: Int) -> Self {
        Self(name: UnsplashQueryName.perPage, value: String(value))
    }

    static func count(_ value: Int) -> Self {
        Self(name: UnsplashQueryName.count, value: String(value))
    }

    static let dailyResolution = Self(
        name: UnsplashQueryName.resolution,
        value: "days"
    )

    static func quantity(_ value: Int) -> Self {
        Self(name: UnsplashQueryName.quantity, value: String(value))
    }
}

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

    var queryParameters: [HTTPQueryParameter] {
        switch self {
        case .photos(let page, let perPage):
            [
                .page(page),
                .perPage(perPage)
            ]

        case .randomPhotos(let count):
            [
                .count(count)
            ]

        case .userPhotos(_, let page, let perPage):
            [
                .page(page),
                .perPage(perPage)
            ]

        case .photoStatistics:
            [
                .dailyResolution,
                .quantity(30)
            ]
        }
    }
}
