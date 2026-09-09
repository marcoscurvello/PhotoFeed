//
//  RemoteImagePipelineTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Remote image pipeline", .serialized)
nonisolated struct RemoteImagePipelineTests {

    @Test("Concurrent requests for the same URL are coalesced")
    func coalescesConcurrentRequests() async throws {
        let counter = RequestCounter()
        let expectedData = Data("image-data".utf8)

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            Thread.sleep(forTimeInterval: 0.05)

            return (
                try makeHTTPResponse(for: request),
                expectedData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        async let first = pipeline.data(for: url)
        async let second = pipeline.data(for: url)

        let (firstData, secondData) = try await (first, second)

        #expect(firstData == expectedData)
        #expect(secondData == expectedData)
        #expect(counter.count == 1)
    }

    @Test("Completed request is served from the memory cache")
    func servesCachedDataWithoutAnotherRequest() async throws {
        let counter = RequestCounter()
        let expectedData = Data("cached-image-data".utf8)

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                expectedData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        let firstData = try await pipeline.data(for: url)
        let secondData = try await pipeline.data(for: url)

        #expect(firstData == expectedData)
        #expect(secondData == expectedData)
        #expect(counter.count == 1)
    }

    @Test("Different URLs produce independent requests")
    func doesNotCoalesceDifferentURLs() async throws {
        let counter = RequestCounter()
        let expectedData = Data("image-data".utf8)

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                expectedData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let firstURL = URL(string: "https://images.example.com/photo-1")!
        let secondURL = URL(string: "https://images.example.com/photo-2")!

        async let first = pipeline.data(for: firstURL)
        async let second = pipeline.data(for: secondURL)

        let (firstData, secondData) = try await (first, second)

        #expect(firstData == expectedData)
        #expect(secondData == expectedData)
        #expect(counter.count == 2)
    }

    @Test("Failed request is cleared and can be retried")
    func retriesAfterFailure() async throws {
        let counter = RequestCounter()
        let expectedData = Data("recovered-image-data".utf8)

        RemoteImageURLProtocolStub.handler = { request in
            let requestNumber = counter.increment()

            if requestNumber == 1 {
                return (
                    try makeHTTPResponse(for: request, statusCode: 500),
                    Data()
                )
            }

            return (
                try makeHTTPResponse(for: request),
                expectedData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        do {
            _ = try await pipeline.data(for: url)
            Issue.record("Expected the first request to fail")
        } catch {
            // Expected
        }

        let recoveredData = try await pipeline.data(for: url)

        #expect(recoveredData == expectedData)
        #expect(counter.count == 2)
    }

    @Test("Removing all cached data forces the image to be requested again")
    func removesAllCachedData() async throws {
        let counter = RequestCounter()
        let expectedData = Data("image-data".utf8)

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                expectedData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        _ = try await pipeline.data(for: url)
        _ = try await pipeline.data(for: url)

        #expect(counter.count == 1)

        await pipeline.removeAllCachedData()

        _ = try await pipeline.data(for: url)

        #expect(counter.count == 2)
    }

    private func makePipeline() -> RemoteImagePipeline {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteImageURLProtocolStub.self]

        let session = URLSession(configuration: configuration)

        return RemoteImagePipeline(session: session)
    }
}

// MARK: - Test support

private func makeHTTPResponse(for request: URLRequest, statusCode: Int = 200) throws -> HTTPURLResponse {
    guard
        let url = request.url,
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    else {
        throw RemoteImagePipelineTestError.invalidResponse
    }

    return response
}

private enum RemoteImagePipelineTestError: Error {
    case invalidResponse
}

private final class RequestCounter: @unchecked Sendable {

    private let lock = NSLock()
    private var value = 0

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        value += 1
        return value
    }

    var count: Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return value
    }
}

private final class RemoteImageURLProtocolStub: URLProtocol, @unchecked Sendable {

    typealias Handler = @Sendable (URLRequest) throws -> (URLResponse, Data)

    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: RemoteImagePipelineTestError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
