//
//  DetailImageVariantTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 16/09/2026.
//

import CoreGraphics
import Foundation
import Testing
@testable import PhotoFeed

@Suite("Detail image variants")
struct DetailImageVariantTests {

    @Test(arguments: [
        (DetailImageVariant.userPhotoThumbnail, CGFloat(1), "160", "1"),
        (.userPhotoThumbnail, 2.4, "160", "2"),
        (.viewer, 2.5, "600", "3"),
        (.viewer, 4, "600", "3"),
        (.viewer, .nan, "600", "1")
    ])
    func appliesExpectedDimensions(
        variant: DetailImageVariant,
        displayScale: CGFloat,
        expectedWidth: String,
        expectedDPR: String
    ) throws {
        let rawURL = try #require(URL(string: "https://images.unsplash.com/photo?ixid=identifier"))
        let url = variant.url(from: rawURL, displayScale: displayScale)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(values["w"] == expectedWidth)
        #expect(values["dpr"] == expectedDPR)
    }
}
