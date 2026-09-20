//
//  RemoteImageRequest.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 20/09/2026.
//

import Foundation

nonisolated struct RemoteImageRequest: Hashable, Sendable {
    let url: URL
    let blurHash: String?

    init(url: URL, blurHash: String? = nil) {
        self.url = url
        self.blurHash = blurHash
    }
}
