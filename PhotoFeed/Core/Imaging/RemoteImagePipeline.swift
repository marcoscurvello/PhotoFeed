//
//  RemoteImagePipeline.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import UIKit

final actor RemoteImagePipeline {

    private struct InFlightRequest {
        let id = UUID()
        let task: Task<UIImage, Error>
    }

    private let session: URLSession
    private let cache: ImageMemoryCache
    private var inFlightRequests: [URL: InFlightRequest] = [:]

    init(session: URLSession = .shared, memoryCapacity: Int = 50 * 1024 * 1024) {
        self.session = session

        cache = ImageMemoryCache(memoryCapacity: memoryCapacity)
    }

    /// Returns an image already prepared by the pipeline, without starting work.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        cache.image(for: url)
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
        let requests = Array(inFlightRequests.values)
        inFlightRequests.removeAll()
        requests.forEach { $0.task.cancel() }
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

    nonisolated private static func prepareImage(from data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        return await image.byPreparingForDisplay()
    }
}
