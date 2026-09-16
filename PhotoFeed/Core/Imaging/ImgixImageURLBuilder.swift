//
//  ImgixImageURLBuilder.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Foundation

nonisolated enum ImgixImageURLBuilder {

    static func url(
        from sourceURL: URL,
        width: Int,
        devicePixelRatio: Int,
        quality: Int = 80
    ) -> URL {
        guard width > 0,
              devicePixelRatio > 0,
              quality > 0,
              let scheme = sourceURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              sourceURL.host != nil,
              var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else {
            return sourceURL
        }

        let transformNames: Set<String> = ["w", "dpr", "fit", "fm", "q"]
        let preservedItems = (components.queryItems ?? []).filter {
            !transformNames.contains($0.name.lowercased())
        }

        components.queryItems = preservedItems + [
            URLQueryItem(name: "w", value: String(width)),
            URLQueryItem(name: "dpr", value: String(devicePixelRatio)),
            URLQueryItem(name: "fit", value: "max"),
            URLQueryItem(name: "fm", value: "jpg"),
            URLQueryItem(name: "q", value: String(quality))
        ]

        return components.url ?? sourceURL
    }
}
