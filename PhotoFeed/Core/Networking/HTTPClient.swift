//
//  HTTPClient.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct HTTPClient: Sendable {

    typealias HTTPResponse = Decodable & Sendable

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: HTTPResponse>(_ request: HTTPRequest) async throws -> Response {
        let data = try await data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func data(for request: HTTPRequest) async throws -> Data {
        let urlRequest = try makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPClientError.unacceptableStatusCode(httpResponse.statusCode, data)
        }

        return data
    }

    private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
        let targetURL = baseURL.appending(path: request.path)

        guard var components = URLComponents(url: targetURL, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw HTTPClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return urlRequest
    }
}
