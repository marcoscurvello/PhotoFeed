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

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCounter?.increment()

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
