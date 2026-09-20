//
//  RemoteImagePipelineTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
import UIKit
@testable import PhotoFeed

@Suite("Remote image pipeline", .serialized)
nonisolated struct RemoteImagePipelineTests {

    @Test("Concurrent callers receive the same prepared image with one fetch", .timeLimit(.minutes(1)))
    func concurrentCallersReceivePreparedImageWithOneFetch() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        async let first = pipeline.image(for: url)
        await responseGate.waitUntilStarted()

        async let second = pipeline.image(for: url)

        await responseGate.release()

        let (firstImage, secondImage) = try await (first, second)

        #expect(firstImage === secondImage)
        #expect(counter.count == 1)
    }

    @Test("Completed request reuses the prepared memory-cached image")
    func reusesPreparedCachedImageWithoutAnotherRequest() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        #expect(pipeline.cachedImage(for: url) == nil)

        let firstImage = try await pipeline.image(for: url)
        let cachedImage = pipeline.cachedImage(for: url)
        let secondImage = try await pipeline.image(for: url)

        #expect(cachedImage === firstImage)
        #expect(firstImage === secondImage)
        #expect(counter.count == 1)
    }

    @Test("Concurrent callers receive the same decoded BlurHash image")
    func concurrentCallersReceiveSameDecodedBlurHashImage() async throws {
        let pipeline = makePipeline()
        let blurHash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj"

        async let first = pipeline.blurHashImage(for: blurHash)
        async let second = pipeline.blurHashImage(for: blurHash)

        let firstImage = try #require(await first)
        let secondImage = try #require(await second)

        #expect(firstImage === secondImage)
        #expect(pipeline.cachedBlurHashImage(for: blurHash) === firstImage)
    }

    @Test("A cached final image emits only the final update")
    func cachedFinalImageEmitsOnlyFinalUpdate() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let blurHash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: blurHash
        )
        _ = try #require(await pipeline.blurHashImage(for: blurHash))
        let cachedImage = try await pipeline.image(for: request.url)

        let updates = try await collectUpdates(from: pipeline, for: request)

        #expect(updates.count == 1)
        guard case .image(let image) = updates[0] else {
            Issue.record("Expected a final image update")
            return
        }
        #expect(image === cachedImage)
        #expect(counter.count == 1)
    }

    @Test("An uncached BlurHash preview is emitted while the final image loads", .timeLimit(.minutes(1)))
    func uncachedBlurHashPreviewIsEmittedWhileFinalImageLoads() async throws {
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        )
        let updates = await pipeline.updates(for: request)
        var iterator = updates.makeAsyncIterator()

        let preview = try #require(try await iterator.next())
        guard case .preview = preview else {
            Issue.record("Expected a BlurHash preview while the final image was blocked")
            return
        }

        await responseGate.release()

        let final = try #require(try await iterator.next())
        guard case .image = final else {
            Issue.record("Expected the final image after releasing the response")
            return
        }

        #expect(try await iterator.next() == nil)
    }

    @Test("A cached BlurHash preview is emitted before the final image")
    func cachedBlurHashPreviewPrecedesFinalImage() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let blurHash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: blurHash
        )
        let preview = try #require(await pipeline.blurHashImage(for: blurHash))

        let updates = try await collectUpdates(from: pipeline, for: request)

        #expect(updates.count == 2)
        guard case .preview(let emittedPreview) = updates[0] else {
            Issue.record("Expected the BlurHash preview first")
            return
        }
        guard case .image = updates[1] else {
            Issue.record("Expected the final image after the preview")
            return
        }
        #expect(emittedPreview === preview)
        #expect(counter.count == 1)
    }

    @Test("Concurrent progressive consumers coalesce the final image fetch", .timeLimit(.minutes(1)))
    func concurrentProgressiveConsumersCoalesceFinalImageFetch() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: nil
        )

        async let first = collectUpdates(from: pipeline, for: request)
        await responseGate.waitUntilStarted()
        async let second = collectUpdates(from: pipeline, for: request)
        await responseGate.release()

        let (firstUpdates, secondUpdates) = try await (first, second)
        #expect(firstUpdates.count == 1)
        #expect(secondUpdates.count == 1)
        #expect(counter.count == 1)
    }

    @Test("Cancelling a progressive consumer preserves shared fetch work", .timeLimit(.minutes(1)))
    func cancellingProgressiveConsumerPreservesSharedFetchWork() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: nil
        )
        let consumer = Task {
            try await self.collectUpdates(from: pipeline, for: request)
        }

        await responseGate.waitUntilStarted()
        consumer.cancel()
        await responseGate.release()

        let cancelledConsumerUpdates = try await consumer.value
        let image = try await pipeline.image(for: request.url)

        #expect(cancelledConsumerUpdates.isEmpty)
        #expect(pipeline.cachedImage(for: request.url) === image)
        #expect(counter.count == 1)
    }

    @Test("A progressive load failure terminates its stream and can be retried")
    func progressiveLoadFailureCanBeRetried() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            let requestNumber = counter.increment()
            if requestNumber == 1 {
                return (try makeHTTPResponse(for: request, statusCode: 500), Data())
            }

            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let request = RemoteImageRequest(
            url: URL(string: "https://images.example.com/photo")!,
            blurHash: nil
        )

        do {
            _ = try await collectUpdates(from: pipeline, for: request)
            Issue.record("Expected the progressive request to fail")
        } catch {
            // Expected
        }

        let updates = try await collectUpdates(from: pipeline, for: request)
        #expect(updates.count == 1)
        #expect(counter.count == 2)
    }

    @Test("Cancelling a caller does not abort or discard the shared fetch", .timeLimit(.minutes(1)))
    func callerCancellationPreservesSharedFetch() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!
        let caller = Task {
            try await pipeline.image(for: url)
        }

        await responseGate.waitUntilStarted()
        caller.cancel()
        await responseGate.release()

        let completedImage = try await caller.value
        let cachedImage = try await pipeline.image(for: url)

        #expect(completedImage === cachedImage)
        #expect(counter.count == 1)
    }

    @Test("Different URLs produce independent requests")
    func doesNotCoalesceDifferentURLs() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let firstURL = URL(string: "https://images.example.com/photo-1")!
        let secondURL = URL(string: "https://images.example.com/photo-2")!

        async let first = pipeline.image(for: firstURL)
        async let second = pipeline.image(for: secondURL)

        _ = try await (first, second)
        #expect(counter.count == 2)
    }

    @Test("Prefetch warms the memory cache", .timeLimit(.minutes(1)))
    func prefetchWarmsMemoryCache() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        await pipeline.prefetch([url])
        await responseGate.waitUntilStarted()
        await responseGate.release()

        let prefetchedImage = try await waitForCachedImage(in: pipeline, for: url)
        let requestedImage = try await pipeline.image(for: url)

        #expect(pipeline.cachedImage(for: url) === prefetchedImage)
        #expect(requestedImage === prefetchedImage)
        #expect(counter.count == 1)
    }

    @Test("Overlapping prefetch calls request each URL only once")
    func overlappingPrefetchCallsRequestEachURLOnlyOnce() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let firstURL = URL(string: "https://images.example.com/photo-1")!
        let secondURL = URL(string: "https://images.example.com/photo-2")!
        let thirdURL = URL(string: "https://images.example.com/photo-3")!

        await pipeline.prefetch([firstURL, secondURL])
        await pipeline.prefetch([secondURL, thirdURL])

        _ = try await pipeline.image(for: firstURL)
        _ = try await pipeline.image(for: secondURL)
        _ = try await pipeline.image(for: thirdURL)

        #expect(counter.count == 3)
    }

    @Test("Prefetch deduplicates URLs within a window")
    func prefetchDeduplicatesURLsWithinAWindow() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        await pipeline.prefetch([url, url, url])
        _ = try await pipeline.image(for: url)

        #expect(counter.count == 1)
    }

    @Test("HTTP failure is cleared and can be retried")
    func retriesAfterHTTPFailure() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

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
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        do {
            _ = try await pipeline.image(for: url)
            Issue.record("Expected the first request to fail")
        } catch {
            // Expected
        }

        let recoveredImage = try await pipeline.image(for: url)

        #expect(recoveredImage.size.width > 0)
        #expect(counter.count == 2)
    }

    @Test("Image decoding failure is cleared and can be retried")
    func retriesAfterImageDecodingFailure() async throws {
        let counter = RequestCounter()

        RemoteImageURLProtocolStub.handler = { request in
            let requestNumber = counter.increment()

            if requestNumber == 1 {
                return (
                    try makeHTTPResponse(for: request),
                    Data("not-an-image".utf8)
                )
            }

            return (
                try makeHTTPResponse(for: request),
                testImageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        do {
            _ = try await pipeline.image(for: url)
            Issue.record("Expected the first request to fail")
        } catch {
            // Expected
        }

        let recoveredImage = try await pipeline.image(for: url)

        #expect(recoveredImage.size.width > 0)
        #expect(counter.count == 2)
    }

    @Test("Removing all cached data forces the image to be requested again")
    func removesAllCachedData() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        _ = try await pipeline.image(for: url)
        _ = try await pipeline.image(for: url)

        #expect(counter.count == 1)
        #expect(pipeline.cachedImage(for: url) != nil)

        await pipeline.removeAllCachedData()

        #expect(pipeline.cachedImage(for: url) == nil)

        _ = try await pipeline.image(for: url)

        #expect(counter.count == 2)
    }

    @Test("Removing all cached data also removes decoded BlurHash images")
    func removesAllCachedBlurHashImages() async throws {
        let pipeline = makePipeline()
        let blurHash = "00TI:j"

        let image = try #require(await pipeline.blurHashImage(for: blurHash))
        #expect(pipeline.cachedBlurHashImage(for: blurHash) === image)

        await pipeline.removeAllCachedData()

        #expect(pipeline.cachedBlurHashImage(for: blurHash) == nil)
    }

    @Test("Removing one cached URL does not evict another URL")
    func removesCachedDataForOneURL() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()

            return (
                try makeHTTPResponse(for: request),
                imageData
            )
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let firstURL = URL(string: "https://images.example.com/photo-1")!
        let secondURL = URL(string: "https://images.example.com/photo-2")!

        _ = try await pipeline.image(for: firstURL)
        _ = try await pipeline.image(for: secondURL)
        await pipeline.removeCachedData(for: firstURL)

        #expect(pipeline.cachedImage(for: firstURL) == nil)
        #expect(pipeline.cachedImage(for: secondURL) != nil)

        _ = try await pipeline.image(for: firstURL)
        _ = try await pipeline.image(for: secondURL)

        #expect(counter.count == 3)
    }

    @Test("Removing cached data permits the URL to be prefetched again")
    func removingCachedDataPermitsReprefetch() async throws {
        let counter = RequestCounter()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        await pipeline.prefetch([url])
        _ = try await pipeline.image(for: url)
        await pipeline.removeCachedData(for: url)

        await pipeline.prefetch([url])
        _ = try await pipeline.image(for: url)

        #expect(counter.count == 2)
    }

    @Test("Removing one URL cancels its in-flight request before it can populate the cache", .timeLimit(.minutes(1)))
    func removingOneURLCancelsItsInFlightRequest() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        await pipeline.prefetch([url])
        await responseGate.waitUntilStarted()
        await pipeline.removeCachedData(for: url)

        #expect(pipeline.cachedImage(for: url) == nil)

        let image = try await pipeline.image(for: url)

        #expect(pipeline.cachedImage(for: url) === image)
        #expect(counter.count == 2)
    }

    @Test("Removing all cached data cancels in-flight requests before they can populate the cache", .timeLimit(.minutes(1)))
    func removingAllCachedDataCancelsInFlightRequests() async throws {
        let counter = RequestCounter()
        let responseGate = ResponseGate()
        let imageData = testImageData

        RemoteImageURLProtocolStub.handler = { request in
            counter.increment()
            await responseGate.markStarted()
            await responseGate.waitForRelease()
            return (try makeHTTPResponse(for: request), imageData)
        }

        defer {
            RemoteImageURLProtocolStub.handler = nil
        }

        let pipeline = makePipeline()
        let url = URL(string: "https://images.example.com/photo")!

        await pipeline.prefetch([url])
        await responseGate.waitUntilStarted()
        await pipeline.removeAllCachedData()

        #expect(pipeline.cachedImage(for: url) == nil)

        let image = try await pipeline.image(for: url)

        #expect(pipeline.cachedImage(for: url) === image)
        #expect(counter.count == 2)
    }

    private func makePipeline() -> RemoteImagePipeline {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteImageURLProtocolStub.self]

        let session = URLSession(configuration: configuration)

        return RemoteImagePipeline(session: session)
    }

    private func waitForCachedImage(
        in pipeline: RemoteImagePipeline,
        for url: URL
    ) async throws -> UIImage {
        for _ in 0..<1_000 {
            if let image = pipeline.cachedImage(for: url) {
                return image
            }

            try await Task.sleep(for: .milliseconds(1))
        }

        throw RemoteImagePipelineTestError.cacheDidNotPopulate
    }

    private func collectUpdates(
        from pipeline: RemoteImagePipeline,
        for request: RemoteImageRequest
    ) async throws -> [RemoteImageContent] {
        var updates: [RemoteImageContent] = []

        for try await update in await pipeline.updates(for: request) {
            updates.append(update)
        }

        return updates
    }
}

private let testImageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL5zwAAAABJRU5ErkJggg==")!

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
    case cacheDidNotPopulate
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

    typealias Handler = @Sendable (URLRequest) async throws -> (URLResponse, Data)

    nonisolated(unsafe) static var handler: Handler?

    private var loadingTask: Task<Void, Never>?

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

        let request = request
        loadingTask = Task { [weak self, request] in
            do {
                let (response, data) = try await handler(request)

                guard !Task.isCancelled, let self else {
                    return
                }

                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                guard !Task.isCancelled, let self else {
                    return
                }

                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

private actor ResponseGate {

    private let startSignal: AsyncStream<Void>
    private let startSignalContinuation: AsyncStream<Void>.Continuation
    private var isReleased = false
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        startSignal = stream
        startSignalContinuation = continuation
    }

    func markStarted() {
        startSignalContinuation.yield(())
        startSignalContinuation.finish()
    }

    func waitUntilStarted() async {
        for await _ in startSignal {
            return
        }
    }

    func waitForRelease() async {
        guard !isReleased else {
            return
        }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if isReleased {
                    continuation.resume()
                } else {
                    releaseWaiters.append(continuation)
                }
            }
        } onCancel: {
            Task {
                await self.release()
            }
        }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
