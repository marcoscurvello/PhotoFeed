//
//  UnsplashAPI.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum UnsplashAPIError: Error, Equatable {
    case invalidRandomPhotoCount(Int)
}

nonisolated struct UnsplashAPI: Sendable {

    private let client: HTTPClient
    private let accessKey: String

    init(client: HTTPClient, accessKey: String) {
        self.client = client
        self.accessKey = accessKey
    }

    func photos(page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await send(.photos(page: page, perPage: perPage))
    }

    func sponsoredPhotos(count: Int) async throws -> [PhotoDTO] {
        try await send(.randomPhotos(count: count))
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await send(.userPhotos(username: username, page: page, perPage: perPage))
    }

    func statistics(photoID: String) async throws -> PhotoStatisticsDTO {
        try await send(.photoStatistics(id: photoID))
    }

    private func send<Response: Decodable & Sendable>(_ endpoint: UnsplashEndpoint) async throws -> Response {
        let request = HTTPRequest(
            path: endpoint.path,
            queryItems: endpoint.queryItems,
            headers: defaultHeaders
        )

        return try await client.send(request)
    }

    private var defaultHeaders: [String: String] {
        [
            "Authorization": "Client-ID \(accessKey)",
            "Accept-Version": "v1"
        ]
    }
}

