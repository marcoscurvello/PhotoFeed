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

        #expect(photos.count == 60)
        #expect(Set(photos.map(\.id)).count == photos.count)
        #expect(photos[0].id == "-oFU4FKenNI")
        #expect(photos[0].user.name == "Sandisk")
        #expect(photos[0].user.username == "sandisk")
        #expect(photos[0].urls.regular.host == "images.unsplash.com")
        #expect(photos[0].blurHash == "LVD+}J4o~pRj_3R.x]tR-q%3t7xa")
        #expect(photos[0].domainModel.blurHash == photos[0].blurHash)
    }

    @Test("Sponsored fixture photos are unique across requests")
    func producesUniqueSponsoredPhotosAcrossRequests() async throws {
        let repository = FixturePhotosRepository()

        let firstBatch = try await repository.sponsoredPhotos(count: 3)
        let secondBatch = try await repository.sponsoredPhotos(count: 3)
        let allPhotos = firstBatch + secondBatch

        #expect(allPhotos.count == 6)
        #expect(Set(allPhotos.map(\.id)).count == allPhotos.count)
        #expect(firstBatch.map(\.id.rawValue) == [
            "fixture-sponsored-0-ScZ_EMuC_lY",
            "fixture-sponsored-1-b1FrQVPyIhQ",
            "fixture-sponsored-2-Xd8ctkMatn8"
        ])
        #expect(secondBatch.map(\.id.rawValue) == [
            "fixture-sponsored-3-ScZ_EMuC_lY",
            "fixture-sponsored-4-b1FrQVPyIhQ",
            "fixture-sponsored-5-Xd8ctkMatn8"
        ])
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
