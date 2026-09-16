//
//  DetailImageVariant.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import CoreGraphics
import Foundation

nonisolated enum DetailImageVariant: Sendable {
    case userPhotoThumbnail
    case viewer

    func url(from rawURL: URL, displayScale: CGFloat) -> URL {
        ImgixImageURLBuilder.url(
            from: rawURL,
            width: logicalWidth,
            devicePixelRatio: normalizedDisplayScale(displayScale)
        )
    }

    private var logicalWidth: Int {
        switch self {
        case .userPhotoThumbnail:
            160
        case .viewer:
            600
        }
    }

    private func normalizedDisplayScale(_ displayScale: CGFloat) -> Int {
        guard displayScale.isFinite else {
            return 1
        }

        return min(max(Int(displayScale.rounded()), 1), 3)
    }
}
