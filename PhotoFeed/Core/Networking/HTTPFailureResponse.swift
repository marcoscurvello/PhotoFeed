//
//  HTTPFailureResponse.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import Foundation

nonisolated struct HTTPFailureResponse: Equatable, Sendable {

    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let retryAfter: Date?

    subscript(header name: String) -> String? {
        headers[name.lowercased()]
    }
}
