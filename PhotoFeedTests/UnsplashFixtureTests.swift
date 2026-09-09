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
        #expect(photos[0].user.name == "Microsoft Copilot")
        #expect(photos[0].user.username == "microsoftcopilot")
        #expect(photos[0].urls.regular.host == "images.unsplash.com")
    }

    @Test("Photo statistics fixture decodes")
    func decodesPhotoStatisticsFixture() throws {
        let statistics: PhotoStatisticsDTO = try FixtureLoader().load(named: "photo_statistics")

        #expect(statistics.id == "pqaA_SBjgEs")
        #expect(statistics.views.total == 147_214)
        #expect(statistics.views.historical.change == 1_705)
        #expect(statistics.views.historical.quantity == 30)
        #expect(statistics.downloads.total == 461)
        #expect(statistics.downloads.historical.change == 24)
        #expect(statistics.likes == nil)
    }
}
