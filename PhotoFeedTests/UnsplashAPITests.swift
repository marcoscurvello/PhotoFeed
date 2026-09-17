//
//  UnsplashAPITests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Unsplash API", .serialized)
nonisolated struct UnsplashAPITests {

    @Test("Random photo count below the supported range is rejected before networking")
    func rejectsZeroRandomPhotoCount() async {
        let requestCounter = RequestCounter()
        let api = makeAPI(requestCounter: requestCounter)
        defer {
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await api.sponsoredPhotos(count: 0)
            Issue.record("Expected count 0 to be rejected")
        } catch let error as UnsplashAPIError {
            #expect(error == .invalidRandomPhotoCount(0))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(requestCounter.count == 0)
    }

    @Test("Random photo count above the supported range is rejected before networking")
    func rejectsRandomPhotoCountAboveThirty() async {
        let requestCounter = RequestCounter()
        let api = makeAPI(requestCounter: requestCounter)
        defer {
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await api.sponsoredPhotos(count: 31)
            Issue.record("Expected count 31 to be rejected")
        } catch let error as UnsplashAPIError {
            #expect(error == .invalidRandomPhotoCount(31))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(requestCounter.count == 0)
    }

    @Test("Minimum supported random photo count reaches networking")
    func acceptsMinimumRandomPhotoCount() async {
        let requestCounter = RequestCounter()
        let api = makeAPI(requestCounter: requestCounter)
        defer {
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await api.sponsoredPhotos(count: 1)
            Issue.record("Expected the stubbed HTTP request to fail")
        } catch let error as UnsplashAPIError {
            Issue.record("Count 1 should be valid, received \(error)")
        } catch {
            // Expected
        }

        #expect(requestCounter.count == 1)
    }

    @Test("Maximum supported random photo count reaches networking")
    func acceptsMaximumRandomPhotoCount() async {
        let requestCounter = RequestCounter()
        let api = makeAPI(requestCounter: requestCounter)
        defer {
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await api.sponsoredPhotos(count: 30)
            Issue.record("Expected the stubbed HTTP request to fail")
        } catch let error as UnsplashAPIError {
            Issue.record("Count 30 should be valid, received \(error)")
        } catch {
            // Expected
        }

        #expect(requestCounter.count == 1)
    }

    @Test("Photo pagination combines the JSON array with response headers")
    func decodesPhotoPaginationMetadata() async throws {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["X-Total": "21", "X-Per-Page": "10"]
                )
            )
            return (response, Data(Self.photoJSON.utf8))
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        let page = try await makeAPI(requestCounter: requestCounter)
            .photosWithMetadata(page: 2, perPage: 10)

        #expect(page.photos.map(\.id) == ["photo-1"])
        #expect(page.page == 2)
        #expect(page.perPage == 10)
        #expect(page.total == 21)
    }

    @Test("Missing or malformed photo pagination headers are rejected")
    func rejectsInvalidPhotoPaginationMetadata() async throws {
        let requestCounter = RequestCounter()
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        let invalidHeaderFields: [[String: String]] = [
            [:],
            ["X-Total": "not-a-number", "X-Per-Page": "10"],
            ["X-Total": "21", "X-Per-Page": "0"],
            ["X-Total": "-1", "X-Per-Page": "10"]
        ]

        for headerFields in invalidHeaderFields {
            UnsplashAPIURLProtocolStub.handler = { request in
                let url = try #require(request.url)
                let response = try #require(
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: headerFields
                    )
                )
                return (response, Data(Self.photoJSON.utf8))
            }

            do {
                _ = try await makeAPI(requestCounter: requestCounter)
                    .photosWithMetadata(page: 1, perPage: 10)
                Issue.record("Expected invalid pagination headers to fail")
            } catch let error as ResourceLoadFailure {
                #expect(error == .invalidResponse)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("Rate-limited responses expose the Unsplash quota and retry deadline")
    func mapsRateLimitedResponse() async throws {
        let requestCounter = RequestCounter()
        let deadline = "120"
        UnsplashAPIURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: [
                        "X-RateLimit-Limit": "50",
                        "X-RateLimit-Remaining": "0",
                        "Retry-After": deadline
                    ]
                )
            )
            return (response, Data(#"{"errors":["Rate Limit Exceeded"]}"#.utf8))
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await makeAPI(requestCounter: requestCounter).photosWithMetadata(page: 1, perPage: 10)
            Issue.record("Expected a rate-limit failure")
        } catch let ResourceLoadFailure.rateLimited(snapshot) {
            #expect(snapshot.limit == 50)
            #expect(snapshot.remaining == 0)
            #expect(snapshot.retryAfter != nil)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("An exhausted rate-limit header makes a 403 response rate limited")
    func mapsExhaustedForbiddenResponse() async throws {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 403,
                    httpVersion: nil,
                    headerFields: [
                        "X-RateLimit-Limit": "50",
                        "X-RateLimit-Remaining": "0"
                    ]
                )
            )
            return (response, Data(#"{"errors":["Missing permissions"]}"#.utf8))
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await makeAPI(requestCounter: requestCounter).photosWithMetadata(page: 1, perPage: 10)
            Issue.record("Expected a rate-limit failure")
        } catch let ResourceLoadFailure.rateLimited(snapshot) {
            #expect(snapshot.limit == 50)
            #expect(snapshot.remaining == 0)
            #expect(snapshot.retryAfter == nil)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A rate-limit error message makes a 403 response rate limited without quota headers")
    func mapsRateLimitErrorMessageWithoutQuotaHeaders() async {
        let expectedFailure = ResourceLoadFailure.rateLimited(
            .init(limit: nil, remaining: nil, retryAfter: nil)
        )

        await assertPhotosRequestMapsToFailure(expectedFailure) { request in
            let response = try Self.response(
                for: request,
                statusCode: 403
            )
            return (response, Data(#"{"errors":["Rate limit exceeded"]}"#.utf8))
        }
    }

    @Test("An ordinary 403 response remains an access failure")
    func mapsForbiddenResponse() async throws {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 403,
                    httpVersion: nil,
                    headerFields: ["X-RateLimit-Remaining": "12"]
                )
            )
            return (response, Data(#"{"errors":["Missing permissions"]}"#.utf8))
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await makeAPI(requestCounter: requestCounter).photosWithMetadata(page: 1, perPage: 10)
            Issue.record("Expected an access failure")
        } catch let failure as ResourceLoadFailure {
            #expect(failure == .accessDenied)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Endpoints without success metadata still map API failures")
    func mapsFailureFromPlainSendEndpoint() async throws {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: [
                        "X-RateLimit-Limit": "50",
                        "X-RateLimit-Remaining": "0"
                    ]
                )
            )
            return (response, Data(#"{"errors":["Rate Limit Exceeded"]}"#.utf8))
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await makeAPI(requestCounter: requestCounter).statistics(photoID: "photo-1")
            Issue.record("Expected a rate-limit failure")
        } catch let ResourceLoadFailure.rateLimited(snapshot) {
            #expect(snapshot.limit == 50)
            #expect(snapshot.remaining == 0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A request timeout response maps to a timeout failure")
    func mapsRequestTimeoutResponse() async {
        await assertPhotosRequestMapsToFailure(.timedOut) { request in
            (try Self.response(for: request, statusCode: 408), Data())
        }
    }

    @Test("A server error preserves a fixed HTTP-date retry deadline")
    func mapsServerFailureWithHTTPDateRetryDeadline() async {
        let deadline = Date(timeIntervalSince1970: 1_784_073_600)

        await assertPhotosRequestMapsToFailure(.serviceUnavailable(retryAfter: deadline)) { request in
            (
                try Self.response(
                    for: request,
                    statusCode: 503,
                    headers: ["Retry-After": "Wed, 15 Jul 2026 00:00:00 GMT"]
                ),
                Data()
            )
        }
    }

    @Test("An offline URL error maps to an offline failure")
    func mapsOfflineURLError() async {
        await assertPhotosRequestMapsToFailure(.offline) { _ in
            throw URLError(.notConnectedToInternet)
        }
    }

    @Test("A timed-out URL error maps to a timeout failure")
    func mapsTimedOutURLError() async {
        await assertPhotosRequestMapsToFailure(.timedOut) { _ in
            throw URLError(.timedOut)
        }
    }

    @Test("Malformed successful JSON maps to an invalid response failure")
    func mapsMalformedSuccessfulJSON() async {
        await assertPhotosRequestMapsToFailure(.invalidResponse) { request in
            (
                try Self.response(
                    for: request,
                    statusCode: 200,
                    headers: ["X-Total": "1", "X-Per-Page": "10"]
                ),
                Data("malformed JSON".utf8)
            )
        }
    }

    @Test("A cancelled URL error remains a cancellation")
    func preservesCancelledURLError() async {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = { _ in
            throw URLError(.cancelled)
        }
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        do {
            _ = try await makeAPI(requestCounter: requestCounter).photosWithMetadata(page: 1, perPage: 10)
            Issue.record("Expected a cancellation")
        } catch is CancellationError {
            // Expected.
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        } catch let error as ResourceLoadFailure {
            Issue.record("Expected cancellation to remain unwrapped, received \(error)")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(requestCounter.count == 1)
    }

    @Test("A not-found response maps to a not-found failure")
    func mapsNotFoundResponse() async {
        await assertPhotosRequestMapsToFailure(.notFound) { request in
            (try Self.response(for: request, statusCode: 404), Data())
        }
    }

    private static let photoJSON = #"""
    [{
      "id": "photo-1", "width": 1200, "height": 800, "color": null,
      "blur_hash": null, "description": null, "alt_description": "A photo",
      "urls": {
        "raw": "https://images.unsplash.com/raw", "full": "https://images.unsplash.com/full",
        "regular": "https://images.unsplash.com/regular", "small": "https://images.unsplash.com/small",
        "thumb": "https://images.unsplash.com/thumb"
      },
      "links": { "html": "https://unsplash.com/photos/photo-1", "download_location": null },
      "user": {
        "id": "user-1", "username": "user", "name": "User",
        "profile_image": { "small": "https://images.unsplash.com/avatar-small", "medium": "https://images.unsplash.com/avatar-medium", "large": "https://images.unsplash.com/avatar-large" },
        "links": { "html": "https://unsplash.com/@user", "photos": "https://api.unsplash.com/users/user/photos" }
      }
    }]
    """#

    private static func response(
        for request: URLRequest,
        statusCode: Int,
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        let url = try #require(request.url)
        return try #require(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )
        )
    }

    private func assertPhotosRequestMapsToFailure(
        _ expectedFailure: ResourceLoadFailure,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) async {
        let requestCounter = RequestCounter()
        UnsplashAPIURLProtocolStub.handler = handler
        defer {
            UnsplashAPIURLProtocolStub.handler = nil
            UnsplashAPIURLProtocolStub.requestCounter = nil
        }

        await #expect(throws: expectedFailure) {
            _ = try await makeAPI(requestCounter: requestCounter)
                .photosWithMetadata(page: 1, perPage: 10)
        }

        #expect(requestCounter.count == 1)
    }

    private func makeAPI(requestCounter: RequestCounter) -> UnsplashAPI {
        UnsplashAPIURLProtocolStub.requestCounter = requestCounter

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnsplashAPIURLProtocolStub.self]

        let client = HTTPClient(
            baseURL: URL(string: "https://api.unsplash.com")!,
            session: URLSession(configuration: configuration)
        )

        return UnsplashAPI(client: client, accessKey: "test-access-key")
    }
}

// MARK: - Test support

private final class RequestCounter: @unchecked Sendable {

    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return value
    }
}

private final class UnsplashAPIURLProtocolStub: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var requestCounter: RequestCounter?
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCounter?.increment()

        if let handler = Self.handler {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        guard
            let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: TestError.invalidResponse)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private enum TestError: Error {
        case invalidResponse
    }
}
