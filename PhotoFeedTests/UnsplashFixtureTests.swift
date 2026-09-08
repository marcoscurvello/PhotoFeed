//
//  UnsplashFixtureTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Unsplash fixtures")
struct UnsplashFixtureTests {

    @Test
    func decodesTodayPhotos() throws {
        let photos: [PhotoDTO] = try FixtureLoader().load(named: "today_photos")

        #expect(!photos.isEmpty)
        #expect(photos[0].id == "oTDuuLUhH20")
        #expect(photos[0].user.username == "microsoftcopilot")
        #expect(photos[0].urls.regular.host == "images.unsplash.com")
    }
}
