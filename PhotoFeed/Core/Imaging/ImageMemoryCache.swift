//
//  ImageMemoryCache.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import UIKit

nonisolated final class ImageMemoryCache: @unchecked Sendable {

    private let storage: NSCache<NSURL, UIImage>

    init(memoryCapacity: Int) {
        let storage = NSCache<NSURL, UIImage>()
        storage.totalCostLimit = memoryCapacity
        self.storage = storage
    }

    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        storage.setObject(image, forKey: url as NSURL, cost: image.decodedBitmapCost)
    }

    func removeImage(for url: URL) {
        storage.removeObject(forKey: url as NSURL)
    }

    func removeAllImages() {
        storage.removeAllObjects()
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
