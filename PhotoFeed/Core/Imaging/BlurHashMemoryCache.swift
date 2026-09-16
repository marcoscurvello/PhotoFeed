//
//  BlurHashMemoryCache.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Foundation
import UIKit

nonisolated final class BlurHashMemoryCache: @unchecked Sendable {

    private let storage: NSCache<NSString, UIImage>

    init(memoryCapacity: Int, countLimit: Int) {
        let storage = NSCache<NSString, UIImage>()
        storage.totalCostLimit = memoryCapacity
        storage.countLimit = countLimit
        self.storage = storage
    }

    func image(for blurHash: String) -> UIImage? {
        storage.object(forKey: blurHash as NSString)
    }

    func insert(_ image: UIImage, for blurHash: String) {
        storage.setObject(image, forKey: blurHash as NSString, cost: image.decodedBitmapCost)
    }

    func removeAllImages() {
        storage.removeAllObjects()
    }
}
