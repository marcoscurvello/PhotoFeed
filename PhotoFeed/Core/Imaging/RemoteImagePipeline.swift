//
//  RemoteImagePipeline.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

actor RemoteImagePipeline {

    private let session: URLSession
    private let cache: NSCache<NSURL, NSData>
    private var inFlightRequests: [URL: Task<Data, Error>] = [:]

    init(session: URLSession = .shared, memoryCapacity: Int = 50 * 1024 * 1024) {
        self.session = session

        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = memoryCapacity
        self.cache = cache
    }

    func data(for url: URL) async throws -> Data {
        if let cachedData = cache.object(forKey: url as NSURL) {
            return cachedData as Data
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

            return data
        }

        inFlightRequests[url] = task

        do {
            let data = try await task.value
            cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
            inFlightRequests[url] = nil
            return data
        } catch {
            inFlightRequests[url] = nil
            throw error
        }
    }

    func removeAllCachedData() {
        cache.removeAllObjects()
    }
}
