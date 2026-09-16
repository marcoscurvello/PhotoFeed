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

        let url = ImgixImageURLBuilder.url(
            from: sourceURL,
            width: 600,
            devicePixelRatio: 3
        )
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

    @Test(arguments: [(0, 1), (160, 0), (160, -1)])
    func returnsOriginalURLForInvalidConfiguration(_ configuration: (Int, Int)) throws {
        let sourceURL = try #require(URL(string: "https://images.unsplash.com/photo?ixid=identifier"))

        #expect(
            ImgixImageURLBuilder.url(
                from: sourceURL,
                width: configuration.0,
                devicePixelRatio: configuration.1
            ) == sourceURL
        )
    }

    @Test("Returns the original URL for a non-web source")
    func returnsOriginalURLForNonWebSource() throws {
        let sourceURL = try #require(URL(string: "file:///photo.jpg"))

        #expect(
            ImgixImageURLBuilder.url(
                from: sourceURL,
                width: 160,
                devicePixelRatio: 2
            ) == sourceURL
        )
    }
}
