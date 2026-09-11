//
//  HTTPClient.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct HTTPClient: Sendable {

    private enum Constants {
        static let retryAfterHeader = "Retry-After"
        static let localeIdentifier = "en_US_POSIX"
        static let dateFormats: [String] = [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy"
        ]
    }

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
            let retryAfter = retryAfter(from: httpResponse, receivedAt: Date())
            throw HTTPClientError.unacceptableStatusCode(httpResponse.statusCode, data, retryAfter: retryAfter)
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

    private func retryAfter(from response: HTTPURLResponse, receivedAt: Date) -> Date? {
        guard let value = response.value(forHTTPHeaderField: Constants.retryAfterHeader)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if value.allSatisfy({ $0.isASCII && $0.isNumber }),
           let seconds = Int(value) {
            return receivedAt.addingTimeInterval(TimeInterval(seconds))
        }

        return formattedDate(value: value)
    }

    private func formattedDate(value: String) -> Date? {
        for format in Constants.dateFormats {

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: Constants.localeIdentifier)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.isLenient = false
            formatter.dateFormat = format

            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
