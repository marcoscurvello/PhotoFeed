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
            } catch let error as UnsplashAPIError {
                #expect(error == .invalidPaginationHeaders)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
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
