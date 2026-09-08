//
//  UnsplashAPI.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct UnsplashAPI: Sendable {

    private let client: HTTPClient
    private let accessKey: String

    init(client: HTTPClient, accessKey: String) {
        self.client = client
        self.accessKey = accessKey
    }

    func photos(page: Int = 1, perPage: Int = 10) async throws -> [PhotoDTO] {
        let request = HTTPRequest(
            path: "photos",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ],
            headers: defaultHeaders
        )

        let photos: [PhotoDTO] = try await client.send(request)
        return photos
    }

    private var defaultHeaders: [String: String] {
        [
            "Authorization": "Client-ID \(accessKey)",
            "Accept-Version": "v1"
        ]
    }
}
