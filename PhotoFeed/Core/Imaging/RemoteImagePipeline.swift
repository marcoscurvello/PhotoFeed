//
//  RemoteImagePipeline.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import UIKit

enum RemoteImageContent {
    case preview(UIImage)
    case image(UIImage)
}

final actor RemoteImagePipeline {

    private enum Constants {
        static let blurHashMemoryCapacity = 2 * 1024 * 1024
        static let blurHashCountLimit = 256
    }

    private struct InFlightImageLoad {
        let id = UUID()
        let task: Task<UIImage, Error>
    }

    private struct InFlightBlurHashDecode {
        let id = UUID()
        let task: Task<UIImage?, Never>
    }

    private let session: URLSession
    private let cache: ImageMemoryCache
    private let blurHashCache: BlurHashMemoryCache
    private var inFlightImageLoads: [URL: InFlightImageLoad] = [:]
    private var inFlightBlurHashDecodes: [String: InFlightBlurHashDecode] = [:]

    init(session: URLSession = .shared, memoryCapacity: Int = 200 * 1024 * 1024) {
        self.session = session

        cache = ImageMemoryCache(memoryCapacity: memoryCapacity)
        blurHashCache = BlurHashMemoryCache(
            memoryCapacity: Constants.blurHashMemoryCapacity,
            countLimit: Constants.blurHashCountLimit
        )
    }

    /// Returns an image already prepared by the pipeline, without starting work.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        cache.image(for: url)
    }

    /// Returns an already decoded BlurHash image without starting work.
    nonisolated func cachedBlurHashImage(for blurHash: String) -> UIImage? {
        blurHashCache.image(for: blurHash)
    }

    /// Returns the best content that is immediately available for a request.
    ///
    /// This is a rendering fast path only. `updates(for:)` remains the source of
    /// truth for loading and must still be consumed by the view.
    nonisolated func cachedContent(for request: RemoteImageRequest) -> RemoteImageContent? {
        if let image = cache.image(for: request.url) {
            return .image(image)
        }

        if let blurHash = request.blurHash, let image = blurHashCache.image(for: blurHash) {
            return .preview(image)
        }

        return nil
    }

    /// Decodes a compact 32×32 BlurHash image, coalescing concurrent work.
    func blurHashImage(for blurHash: String) async -> UIImage? {
        if let cachedImage = blurHashCache.image(for: blurHash) {
            return cachedImage
        }

        if let existingDecode = inFlightBlurHashDecodes[blurHash] {
            return await resolve(existingDecode, for: blurHash)
        }

        let decode = InFlightBlurHashDecode(
            task: Task.detached(priority: .userInitiated) {
                BlurHashDecoder.decode(blurHash)
            }
        )
        inFlightBlurHashDecodes[blurHash] = decode

        return await resolve(decode, for: blurHash)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = cache.image(for: url) {
            return cachedImage
        }

        if let existingLoad = inFlightImageLoads[url] {
            return try await resolve(existingLoad, for: url)
        }

        let load = InFlightImageLoad(task: makeImageLoadTask(for: url))

        inFlightImageLoads[url] = load
        return try await resolve(load, for: url)
    }

    /// Emits the best available preview followed by the final image.
    ///
    /// The stream is consumer-scoped: cancelling iteration stops delivery to that
    /// consumer but leaves the pipeline's shared image and BlurHash work intact.
    func updates(for request: RemoteImageRequest) -> AsyncThrowingStream<RemoteImageContent, Error> {
        AsyncThrowingStream { continuation in
            let deliveryTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                await self.produceUpdates(for: request, continuation: continuation)
            }

            continuation.onTermination = { @Sendable _ in
                deliveryTask.cancel()
            }
        }
    }

    /// Starts image requests for the supplied URLs when they are not cached or in flight.
    ///
    /// The work is deliberately unstructured so callers can update a scrolling
    /// window without waiting for network or image decoding work to finish.
    func prefetch(_ urls: [URL]) {
        for url in urls {
            guard cache.image(for: url) == nil, inFlightImageLoads[url] == nil else {
                continue
            }

            let load = InFlightImageLoad(task: makeImageLoadTask(for: url))
            inFlightImageLoads[url] = load

            Task { [weak self, load] in
                _ = try? await self?.resolve(load, for: url)
            }
        }
    }

    func removeCachedData(for url: URL) {
        cache.removeImage(for: url)
        inFlightImageLoads.removeValue(forKey: url)?.task.cancel()
    }

    func removeAllCachedData() {
        cache.removeAllImages()
        blurHashCache.removeAllImages()

        let imageLoads = Array(inFlightImageLoads.values)
        inFlightImageLoads.removeAll()
        imageLoads.forEach { $0.task.cancel() }

        let blurHashDecodes = Array(inFlightBlurHashDecodes.values)
        inFlightBlurHashDecodes.removeAll()
        blurHashDecodes.forEach { $0.task.cancel() }
    }

    private func makeImageLoadTask(for url: URL) -> Task<UIImage, Error> {
        let session = session

        return Task {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            guard let image = await Self.prepareImage(from: data) else {
                throw URLError(.cannotDecodeContentData)
            }

            return image
        }
    }

    private func resolve(_ load: InFlightImageLoad, for url: URL) async throws -> UIImage {
        do {
            let image = try await load.task.value

            if inFlightImageLoads[url]?.id == load.id {
                cache.insert(image, for: url)
                inFlightImageLoads[url] = nil
            }

            return image
        } catch {
            if inFlightImageLoads[url]?.id == load.id {
                inFlightImageLoads[url] = nil
            }

            throw error
        }
    }

    private func resolve(_ decode: InFlightBlurHashDecode, for blurHash: String) async -> UIImage? {
        let image = await decode.task.value

        if inFlightBlurHashDecodes[blurHash]?.id == decode.id {
            if let image {
                blurHashCache.insert(image, for: blurHash)
            }

            inFlightBlurHashDecodes[blurHash] = nil
        }

        return image
    }

    private func produceUpdates(
        for request: RemoteImageRequest,
        continuation: AsyncThrowingStream<RemoteImageContent, Error>.Continuation
    ) async {
        if let image = cache.image(for: request.url) {
            continuation.yield(.image(image))
            continuation.finish()
            return
        }

        let needsBlurHashDecode: Bool
        if let blurHash = request.blurHash, let image = blurHashCache.image(for: blurHash) {
            continuation.yield(.preview(image))
            needsBlurHashDecode = false
        } else {
            needsBlurHashDecode = request.blurHash != nil
        }

        do {
            try await withThrowingTaskGroup(of: RemoteImageContent?.self) { group in
                if needsBlurHashDecode {
                    group.addTask { [weak self] in
                        guard let self, let blurHash = request.blurHash,
                              let image = await self.blurHashImage(for: blurHash) else {
                            return nil
                        }

                        return .preview(image)
                    }
                }

                group.addTask { [weak self] in
                    guard let self else {
                        throw CancellationError()
                    }

                    return .image(try await self.image(for: request.url))
                }

                while let update = try await group.next() {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        return
                    }

                    guard let update else {
                        continue
                    }

                    switch update {
                        case .preview:
                            continuation.yield(update)

                        case .image:
                            group.cancelAll()
                            continuation.yield(update)
                            continuation.finish()
                            return
                    }
                }
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            continuation.finish(throwing: error)
        }
    }

    nonisolated private static func prepareImage(from data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        return await image.byPreparingForDisplay()
    }
}
