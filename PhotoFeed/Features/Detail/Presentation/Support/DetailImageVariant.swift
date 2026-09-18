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
        guard let transform = ImgixImageURLBuilder.Transform(
            width: logicalWidth,
            devicePixelRatio: normalizedDevicePixelRatio(displayScale)
        ) else {
            return rawURL
        }

        return ImgixImageURLBuilder.url(from: rawURL, applying: transform)
    }

    private var logicalWidth: Int {
        switch self {
        case .userPhotoThumbnail:
            160
        case .viewer:
            600
        }
    }

    private func normalizedDevicePixelRatio(
        _ displayScale: CGFloat
    ) -> ImgixImageURLBuilder.Transform.DevicePixelRatio {
        guard displayScale.isFinite else {
            return .x1
        }

        switch min(max(Int(displayScale.rounded()), 1), 3) {
        case 2: return .x2
        case 3: return .x3
        default: return .x1
        }
    }
}
