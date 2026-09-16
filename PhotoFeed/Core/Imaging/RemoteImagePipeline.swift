//
//  RemoteImagePipeline.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import UIKit

final actor RemoteImagePipeline {

    private enum Constants {
        static let placeholderMemoryCapacity = 2 * 1024 * 1024
        static let placeholderCountLimit = 256
    }

    private struct InFlightRequest {
        let id = UUID()
        let task: Task<UIImage, Error>
    }

    private struct InFlightPlaceholder {
        let id = UUID()
        let task: Task<UIImage?, Never>
    }

    private let session: URLSession
    private let cache: ImageMemoryCache
    private let placeholderCache: BlurHashMemoryCache
    private var inFlightRequests: [URL: InFlightRequest] = [:]
    private var inFlightPlaceholders: [String: InFlightPlaceholder] = [:]

    init(session: URLSession = .shared, memoryCapacity: Int = 50 * 1024 * 1024) {
        self.session = session

        cache = ImageMemoryCache(memoryCapacity: memoryCapacity)
        placeholderCache = BlurHashMemoryCache(
            memoryCapacity: Constants.placeholderMemoryCapacity,
            countLimit: Constants.placeholderCountLimit
        )
    }

    /// Returns an image already prepared by the pipeline, without starting work.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        cache.image(for: url)
    }

    /// Returns an already decoded BlurHash placeholder without starting work.
    nonisolated func cachedPlaceholder(for blurHash: String) -> UIImage? {
        placeholderCache.image(for: blurHash)
    }

    /// Decodes a compact 32×32 BlurHash placeholder, coalescing concurrent work.
    func placeholder(for blurHash: String) async -> UIImage? {
        if let cachedImage = placeholderCache.image(for: blurHash) {
            return cachedImage
        }

        if let existingPlaceholder = inFlightPlaceholders[blurHash] {
            return await resolve(existingPlaceholder, for: blurHash)
        }

        let placeholder = InFlightPlaceholder(
            task: Task.detached(priority: .userInitiated) {
                BlurHashDecoder.decode(blurHash)
            }
        )
        inFlightPlaceholders[blurHash] = placeholder

        return await resolve(placeholder, for: blurHash)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = cache.image(for: url) {
            return cachedImage
        }

        if let existingRequest = inFlightRequests[url] {
            return try await resolve(existingRequest, for: url)
        }

        let request = InFlightRequest(task: makeRequestTask(for: url))

        inFlightRequests[url] = request
        return try await resolve(request, for: url)
    }

    /// Starts image requests for the supplied URLs when they are not cached or in flight.
    ///
    /// The work is deliberately unstructured so callers can update a scrolling
    /// window without waiting for network or image decoding work to finish.
    func prefetch(_ urls: [URL]) {
        for url in urls {
            guard cache.image(for: url) == nil, inFlightRequests[url] == nil else {
                continue
            }

            let request = InFlightRequest(task: makeRequestTask(for: url))
            inFlightRequests[url] = request

            Task { [weak self, request] in
                _ = try? await self?.resolve(request, for: url)
            }
        }
    }

    func removeCachedData(for url: URL) {
        cache.removeImage(for: url)
        inFlightRequests.removeValue(forKey: url)?.task.cancel()
    }

    func removeAllCachedData() {
        cache.removeAllImages()
        placeholderCache.removeAllImages()

        let requests = Array(inFlightRequests.values)
        inFlightRequests.removeAll()
        requests.forEach { $0.task.cancel() }

        let placeholders = Array(inFlightPlaceholders.values)
        inFlightPlaceholders.removeAll()
        placeholders.forEach { $0.task.cancel() }
    }

    private func makeRequestTask(for url: URL) -> Task<UIImage, Error> {
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

    private func resolve(_ request: InFlightRequest, for url: URL) async throws -> UIImage {
        do {
            let image = try await request.task.value

            if inFlightRequests[url]?.id == request.id {
                cache.insert(image, for: url)
                inFlightRequests[url] = nil
            }

            return image
        } catch {
            if inFlightRequests[url]?.id == request.id {
                inFlightRequests[url] = nil
            }

            throw error
        }
    }

    private func resolve(_ placeholder: InFlightPlaceholder, for blurHash: String) async -> UIImage? {
        let image = await placeholder.task.value

        if inFlightPlaceholders[blurHash]?.id == placeholder.id {
            if let image {
                placeholderCache.insert(image, for: blurHash)
            }

            inFlightPlaceholders[blurHash] = nil
        }

        return image
    }

    nonisolated private static func prepareImage(from data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        return await image.byPreparingForDisplay()
    }
}
