//
//  RemoteImagePipeline.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import UIKit

actor RemoteImagePipeline {

    private let session: URLSession
    private let cache: NSCache<NSURL, UIImage>
    private var inFlightRequests: [URL: Task<UIImage, Error>] = [:]

    init(session: URLSession = .shared, memoryCapacity: Int = 50 * 1024 * 1024) {
        self.session = session

        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = memoryCapacity
        self.cache = cache
    }

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }

        if let existingRequest = inFlightRequests[url] {
            return try await existingRequest.value
        }

        let task = Task {
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

        inFlightRequests[url] = task

        do {
            let image = try await task.value
            cache.setObject(image, forKey: url as NSURL, cost: image.decodedBitmapCost)
            inFlightRequests[url] = nil
            return image
        } catch {
            inFlightRequests[url] = nil
            throw error
        }
    }

    func removeCachedData(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    func removeAllCachedData() {
        cache.removeAllObjects()
    }

    nonisolated private static func prepareImage(from data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        return await image.byPreparingForDisplay()
    }
}

private extension UIImage {

    nonisolated var decodedBitmapCost: Int {
        if let cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }

        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        return max(1, Int(pixelWidth * pixelHeight * 4))
    }
}
