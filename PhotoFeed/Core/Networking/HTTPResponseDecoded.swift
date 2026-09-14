//
//  HTTPResponseDecoded.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 14/09/2026.
//

import Foundation

typealias HTTPResponse = Decodable & Sendable

nonisolated struct HTTPResponseDecoded<Value: HTTPResponse>: Sendable {
    let value: Value
    let headers: [String: String]

    subscript(header name: String) -> String? {
        headers[name.lowercased()]
    }
}
