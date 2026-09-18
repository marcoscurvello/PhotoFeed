//
//  HTTPClientError.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

nonisolated enum HTTPClientError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unacceptableResponse(HTTPFailureResponse)
}
