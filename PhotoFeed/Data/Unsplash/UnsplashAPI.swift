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

    private enum HeaderKeys {
        static let authorization = "Authorization"
        static let version = "Accept-Version"
        static let perPage = "x-per-page"
        static let paginationTotal = "x-total"
        static let rateLimit = "x-ratelimit-limit"
        static let rateLimitRemaining = "x-ratelimit-remaining"
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
            throw ResourceLoadFailure.invalidResponse
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
        do {
            return try await client.send(request(for: endpoint))
        } catch {
            throw mappedError(from: error)
        }
    }

    private func sendWithMetadata<Response: HTTPResponse>(_ endpoint: UnsplashEndpoint) async throws -> HTTPResponseDecoded<Response> {
        do {
            return try await client.sendWithMetadata(request(for: endpoint))
        } catch {
            throw mappedError(from: error)
        }
    }

    private func mappedError(from error: Error) -> Error {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return error
        }

        if let failure = error as? ResourceLoadFailure {
            return failure
        }

        guard case let HTTPClientError.unacceptableResponse(response) = error else {
            return networkFailure(from: error)
        }

        let errors = (try? JSONDecoder().decode(UnsplashErrorResponse.self, from: response.body))?.errors ?? []

        return switch response.statusCode {
            case 408:
                ResourceLoadFailure.timedOut
            case 429:
                ResourceLoadFailure.rateLimited(rateLimitSnapshot(from: response))
            case 403 where rateLimitSnapshot(from: response).remaining == 0 || errors.contains(where: isRateLimitError):
                ResourceLoadFailure.rateLimited(rateLimitSnapshot(from: response))
            case 401, 403:
                ResourceLoadFailure.accessDenied
            case 404:
                ResourceLoadFailure.notFound
            case 500..<600:
                ResourceLoadFailure.serviceUnavailable(retryAfter: response.retryAfter)
            default:
                ResourceLoadFailure.invalidResponse
        }
    }

    private func networkFailure(from error: Error) -> ResourceLoadFailure {
        switch error {
            case let urlError as URLError:
                switch urlError.code {
                    case .timedOut:
                            .timedOut
                    case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff,
                            .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .callIsActive:
                            .offline
                    default:
                            .unknown
                }
            case is DecodingError, HTTPClientError.invalidURL, HTTPClientError.invalidResponse:
                    .invalidResponse
            default:
                    .unknown
        }
    }

    private func rateLimitSnapshot(from response: HTTPFailureResponse) -> RateLimitSnapshot {
        RateLimitSnapshot(
            limit: response[header: HeaderKeys.rateLimit].flatMap(Int.init),
            remaining: response[header: HeaderKeys.rateLimitRemaining].flatMap(Int.init),
            retryAfter: response.retryAfter
        )
    }

    private func isRateLimitError(_ message: String) -> Bool {
        message.range(of: "rate limit", options: .caseInsensitive) != nil
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

nonisolated private struct UnsplashErrorResponse: Decodable, Sendable {
    let errors: [String]
}
