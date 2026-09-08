//
//  SponsoredInsertionPolicyTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Sponsored insertion policy")
struct SponsoredInsertionPolicyTests {

    @Test("First sponsored item is inserted immediately below the current position")
    func firstSponsoredItemIsInsertedBelowCurrentPosition() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            organic("p2"),
            organic("p3"),
            organic("p4")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 0)

        #expect(insertionIndex == 1)
    }

    @Test("First sponsored item never inserts above the current position")
    func firstSponsoredItemRespectsCurrentPosition() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            organic("p2"),
            organic("p3"),
            organic("p4"),
            organic("p5")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 3)

        #expect(insertionIndex == 4)
    }

    @Test("Next sponsored item is inserted after the configured number of organic items")
    func respectsConfiguredCadence() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            sponsored("sp1"),
            organic("p2"),
            organic("p3"),
            organic("p4"),
            organic("p5")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 0)

        #expect(insertionIndex == 5)
    }

    @Test("Late sponsored item is inserted below the current position")
    func lateSponsoredItemDoesNotBackInsert() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            sponsored("sp1"),
            organic("p2"),
            organic("p3"),
            organic("p4"),
            organic("p5")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 5)

        #expect(insertionIndex == 6)
    }

    @Test("Sponsored item waits until enough organic items have appeared")
    func waitsForCadenceToBecomeDue() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            sponsored("sp1"),
            organic("p2"),
            organic("p3")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 0)

        #expect(insertionIndex == nil)
    }

    @Test("Cadence restarts from the most recently inserted sponsored item")
    func cadenceRestartsFromLastSponsoredItem() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3)
        let items = [
            organic("p1"),
            sponsored("sp1"),
            organic("p2"),
            organic("p3"),
            organic("p4"),
            sponsored("sp2"),
            organic("p5"),
            organic("p6"),
            organic("p7")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 0)

        #expect(insertionIndex == 9)
    }

    @Test("Insertion frequency is configurable")
    func supportsCustomCadence() {
        let policy = SponsoredInsertionPolicy(organicItemsBetweenSponsored: 2)
        let items = [
            organic("p1"),
            sponsored("sp1"),
            organic("p2"),
            organic("p3"),
            organic("p4")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 0)

        #expect(insertionIndex == 4)
    }

    @Test("Empty feed has no valid insertion point")
    func emptyFeedReturnsNil() {
        let policy = SponsoredInsertionPolicy()

        let insertionIndex = policy.insertionIndex(in: [], currentVisibleIndex: 0)

        #expect(insertionIndex == nil)
    }

    @Test("Visible index beyond the loaded feed is safely clamped")
    func visibleIndexBeyondFeedIsClamped() {
        let policy = SponsoredInsertionPolicy()
        let items = [
            organic("p1"),
            organic("p2")
        ]

        let insertionIndex = policy.insertionIndex(in: items, currentVisibleIndex: 100)

        #expect(insertionIndex == 2)
    }
}

private func organic(_ id: String) -> TodayFeedItem {
    .organic(makePhoto(id))
}

private func sponsored(_ id: String) -> TodayFeedItem {
    .sponsored(makePhoto(id))
}

private func makePhoto(_ id: String) -> Photo {
    let imageURL = URL(string: "https://images.unsplash.com/photo-\(id)")!
    let webpageURL = URL(string: "https://unsplash.com/photos/\(id)")!

    return Photo(
        id: .init(rawValue: id),
        width: 1200,
        height: 1600,
        colorHex: nil,
        description: nil,
        imageURLs: .init(full: imageURL, regular: imageURL, small: imageURL, thumbnail: imageURL),
        user: makeUser(id),
        webpageURL: webpageURL
    )
}

private func makeUser(_ id: String) -> User {
    User(
        id: .init(rawValue: "user-\(id)"),
        username: "user-\(id)",
        name: "User \(id)",
        avatarURL: URL(string: "https://images.unsplash.com/profile-\(id)")!,
        webpageURL: URL(string: "https://unsplash.com/@user-\(id)")!
    )
}
