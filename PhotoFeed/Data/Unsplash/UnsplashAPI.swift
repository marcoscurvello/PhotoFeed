//
//  UnsplashAPI.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum UnsplashAPIError: Error, Equatable {
    case invalidRandomPhotoCount(Int)
    case invalidPaginationHeaders
}

nonisolated struct UnsplashAPI: Sendable {

    private enum HeaderKeys {
        static let authorization = "Authorization"
        static let version = "Accept-Version"
        static let perPage = "x-per-page"
        static let paginationTotal = "x-total"
    }

    private let client: HTTPClient
    private let accessKey: String

    init(client: HTTPClient, accessKey: String) {
        self.client = client
        self.accessKey = accessKey
    }

    func photosWithMetadata(page: Int, perPage: Int) async throws -> PhotoPageDTO {
        let response: HTTPResponseDecoded<[PhotoDTO]> = try await sendWithMetadata(.photos(page: page, perPage: perPage))

        guard let totalValue = response[header: HeaderKeys.paginationTotal],
              let total = Int(totalValue), total >= 0,
              let perPageValue = response[header: HeaderKeys.perPage],
              let responsePerPage = Int(perPageValue), responsePerPage > 0 else {
            throw UnsplashAPIError.invalidPaginationHeaders
        }

        return PhotoPageDTO(
            photos: response.value,
            page: page,
            perPage: responsePerPage,
            total: total
        )
    }

    func sponsoredPhotos(count: Int) async throws -> [PhotoDTO] {
        guard (1...30).contains(count) else {
            throw UnsplashAPIError.invalidRandomPhotoCount(count)
        }

        return try await send(.randomPhotos(count: count))
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await send(.userPhotos(username: username, page: page, perPage: perPage))
    }

    func statistics(photoID: String) async throws -> PhotoStatisticsDTO {
        try await send(.photoStatistics(id: photoID))
    }

    private func send<Response: HTTPResponse>(_ endpoint: UnsplashEndpoint) async throws -> Response {
        try await client.send(request(for: endpoint))
    }

    private func sendWithMetadata<Response: HTTPResponse>(_ endpoint: UnsplashEndpoint) async throws -> HTTPResponseDecoded<Response> {
        try await client.sendWithMetadata(request(for: endpoint))
    }

    private func request(for endpoint: UnsplashEndpoint) -> HTTPRequest {
        HTTPRequest(
            path: endpoint.path,
            queryParameters: endpoint.queryParameters,
            headers: defaultHeaders
        )
    }

    private var defaultHeaders: [String: String] {
        [
            HeaderKeys.authorization: "Client-ID \(accessKey)",
            HeaderKeys.version: "v1"
        ]
    }
}
