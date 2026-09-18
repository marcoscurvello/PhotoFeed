//
//  ImgixImageURLBuilderTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Imgix image URL builder")
struct ImgixImageURLBuilderTests {

    @Test("Preserves source tracking parameters and replaces image transforms")
    func preservesTrackingParametersAndReplacesTransforms() throws {
        let sourceURL = try #require(URL(string: "https://images.unsplash.com/photo?ixid=identifier&ixlib=rb-4.1.0&crop=entropy&cs=tinysrgb&w=1080&dpr=1&fit=crop&fm=webp&q=20"))
        let transform = try #require(
            ImgixImageURLBuilder.Transform(
                width: 600,
                devicePixelRatio: .x3
            )
        )

        let url = ImgixImageURLBuilder.url(from: sourceURL, applying: transform)

        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(queryItems.map(\.name) == ["ixid", "ixlib", "crop", "cs", "w", "dpr", "fit", "fm", "q"])

        let values = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        #expect(values == [
            "ixid": "identifier",
            "ixlib": "rb-4.1.0",
            "crop": "entropy",
            "cs": "tinysrgb",
            "w": "600",
            "dpr": "3",
            "fit": "max",
            "fm": "jpg",
            "q": "80"
        ])
    }

    @Test(arguments: [
        (0, 80),
        (-1, 80),
        (160, -1),
        (160, 101)
    ])
    func rejectsInvalidTransform(_ configuration: (width: Int, quality: Int)) {
        let transform = ImgixImageURLBuilder.Transform(
            width: configuration.width,
            devicePixelRatio: .x2,
            quality: configuration.quality
        )

        #expect(transform == nil)
    }

    @Test(
        "Returns the original URL for an unsupported source",
        arguments: ["file:///photo.jpg", "https:///photo.jpg"]
    )
    func returnsOriginalURLForUnsupportedSource(_ source: String) throws {
        let sourceURL = try #require(URL(string: source))
        let transform = try #require(
            ImgixImageURLBuilder.Transform(
                width: 160,
                devicePixelRatio: .x2
            )
        )

        let url = ImgixImageURLBuilder.url(from: sourceURL, applying: transform)

        #expect(url == sourceURL)
    }

    @Test("Accepts the complete Imgix quality range", arguments: [0, 100])
    func acceptsQualityBoundary(_ quality: Int) {
        let transform = ImgixImageURLBuilder.Transform(
            width: 160,
            devicePixelRatio: .x2,
            quality: quality
        )

        #expect(transform != nil)
    }
}
