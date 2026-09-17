//
//  HTTPClient.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct HTTPClient: Sendable {

    private enum HeaderKeys {
        static let retryAfter = "Retry-After"
    }

    private enum Constants {
        static let localeIdentifier = "en_US_POSIX"
        static let dateFormats: [String] = [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy"
        ]
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: HTTPResponse>(_ request: HTTPRequest) async throws -> Response {
        let response = try await response(for: request)
        return try JSONDecoder().decode(Response.self, from: response.data)
    }

    func sendWithMetadata<Response: HTTPResponse>(_ request: HTTPRequest) async throws -> HTTPResponseDecoded<Response> {
        let response = try await response(for: request)
        let value = try JSONDecoder().decode(Response.self, from: response.data)

        return HTTPResponseDecoded(value: value, headers: response.headers)
    }

    func data(for request: HTTPRequest) async throws -> Data {
        let response = try await response(for: request)
        return response.data
    }

    private func response(for request: HTTPRequest) async throws -> (data: Data, headers: [String: String]) {
        let urlRequest = try makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        let headers = normalizedHeaders(from: httpResponse)

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPClientError.unacceptableResponse(
                HTTPFailureResponse(
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    body: data,
                    retryAfter: retryAfter(from: headers, receivedAt: Date())
                )
            )
        }

        return (data, headers)
    }

    private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
        let targetURL = baseURL.appending(path: request.path)

        guard var components = URLComponents(url: targetURL, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }

        if !request.queryParameters.isEmpty {
            components.queryItems = request.queryParameters.map(\.urlQueryItem)
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

    private func normalizedHeaders(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, field in
            guard let name = field.key as? String else {
                return
            }

            headers[name.lowercased()] = String(describing: field.value)
        }
    }

    private func retryAfter(from headers: [String: String], receivedAt: Date) -> Date? {
        guard let value = headers[HeaderKeys.retryAfter.lowercased()]?.trimmingCharacters(in: .whitespacesAndNewlines),
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
