//
//  ImgixImageURLBuilder.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Foundation

nonisolated private enum ImgixQueryName: String, CaseIterable {
    case width = "w"
    case devicePixelRatio = "dpr"
    case fit
    case format = "fm"
    case quality = "q"

    static let overriddenNames = Set(allCases.map(\.rawValue))
}

nonisolated private extension HTTPQueryParameter {

    static let fitMax = Self(name: ImgixQueryName.fit, value: "max")
    static let jpeg = Self(name: ImgixQueryName.format, value: "jpg")

    static func width(_ value: Int) -> Self {
        Self(name: ImgixQueryName.width, value: String(value))
    }

    static func devicePixelRatio(_ value: ImgixImageURLBuilder.Transform.DevicePixelRatio) -> Self {
        Self(name: ImgixQueryName.devicePixelRatio, value: String(value.rawValue))
    }

    static func quality(_ value: Int) -> Self {
        Self(name: ImgixQueryName.quality, value: String(value))
    }
}

nonisolated enum ImgixImageURLBuilder {

    private enum Constants {
        static let schemes: Set<String> = ["http", "https"]
    }

    struct Transform: Sendable {
        enum DevicePixelRatio: Int, Sendable {
            case x1 = 1
            case x2 = 2
            case x3 = 3
        }

        let width: Int
        let devicePixelRatio: DevicePixelRatio
        let quality: Int

        init?(width: Int, devicePixelRatio: DevicePixelRatio, quality: Int = 80) {
            guard width > 0, (0...100).contains(quality) else {
                return nil
            }

            self.width = width
            self.devicePixelRatio = devicePixelRatio
            self.quality = quality
        }
    }

    static func url(from sourceURL: URL, applying transform: Transform) -> URL {
        guard let scheme = sourceURL.scheme?.lowercased(), Constants.schemes.contains(scheme), sourceURL.host != nil,
              var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else {
            return sourceURL
        }

        let preservedItems = (components.queryItems ?? []).filter {
            !ImgixQueryName.overriddenNames.contains($0.name.lowercased())
        }

        let parameters: [HTTPQueryParameter] = [
            .width(transform.width),
            .devicePixelRatio(transform.devicePixelRatio),
            .fitMax,
            .jpeg,
            .quality(transform.quality)
        ]
        components.queryItems = preservedItems + parameters.map(\.urlQueryItem)

        return components.url ?? sourceURL
    }
}
