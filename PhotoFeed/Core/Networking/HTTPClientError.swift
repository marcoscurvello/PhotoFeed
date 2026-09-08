//
//  HTTPClientError.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum HTTPClientError: Error {
    case invalidURL
    case invalidResponse
    case unacceptableStatusCode(Int, Data)
}
