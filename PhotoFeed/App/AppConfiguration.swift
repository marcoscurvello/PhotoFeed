//
//  AppConfiguration.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum AppConfigurationError: Error, Equatable {
    case missingUnsplashAccessKey
}

nonisolated struct AppConfiguration: Sendable {

    let unsplashAccessKey: String

    init(bundle: Bundle = .main) throws {
        guard let accessKey = bundle.object(forInfoDictionaryKey: "UNSPLASH_ACCESS_KEY") as? String,
              !accessKey.isEmpty,
              accessKey != "$(UNSPLASH_ACCESS_KEY)" else {
            throw AppConfigurationError.missingUnsplashAccessKey
        }

        self.unsplashAccessKey = accessKey
    }
}
