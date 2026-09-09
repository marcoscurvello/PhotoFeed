//
//  UnsplashEndpointTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Unsplash endpoints")
struct UnsplashEndpointTests {

    @Test("Photos endpoint")
    func photos() {
        let endpoint = UnsplashEndpoint.photos(page: 2, perPage: 10)

        #expect(endpoint.path == "photos")
        #expect(
            endpoint.queryItems == [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "per_page", value: "10")
            ]
        )
    }

    @Test("Random photos endpoint")
    func randomPhotos() {
        let endpoint = UnsplashEndpoint.randomPhotos(count: 3)

        #expect(endpoint.path == "photos/random")
        #expect(
            endpoint.queryItems == [
                URLQueryItem(name: "count", value: "3")
            ]
        )
    }

    @Test("User photos endpoint")
    func userPhotos() {
        let endpoint = UnsplashEndpoint.userPhotos(
            username: "morpheus",
            page: 2,
            perPage: 10
        )

        #expect(endpoint.path == "users/morpheus/photos")
        #expect(
            endpoint.queryItems == [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "per_page", value: "10")
            ]
        )
    }

    @Test("Photo statistics endpoint")
    func statistics() {
        let endpoint = UnsplashEndpoint.photoStatistics(id: "pqaA_SBjgEs")

        #expect(endpoint.path == "photos/pqaA_SBjgEs/statistics")
        #expect(
            endpoint.queryItems == [
                URLQueryItem(name: "resolution", value: "days"),
                URLQueryItem(name: "quantity", value: "30")
            ]
        )
    }
}
