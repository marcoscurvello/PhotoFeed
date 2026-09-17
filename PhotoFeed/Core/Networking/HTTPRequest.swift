//
//  HTTPRequest.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct HTTPRequest: Sendable {

    let path: String
    let method: HTTPMethod
    let queryParameters: [HTTPQueryParameter]
    let headers: [String: String]

    init(
        path: String,
        method: HTTPMethod = .get,
        queryParameters: [HTTPQueryParameter] = [],
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryParameters = queryParameters
        self.headers = headers
    }
}
