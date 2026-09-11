//
//  TodayViewModelTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Observation
import Testing
@testable import PhotoFeed

@Suite("Today view model", .timeLimit(.minutes(1)))
struct TodayViewModelTests {

    @Test("Loads unique organic pages, preserves styles, and stops after a partial page")
    @MainActor
    func loadsOrganicPagesAndStopsAfterPartialPage() async {
        let pageOne = (1...10).map { makePhoto(id: "p\($0)") }
        let pageTwo = [
            makePhoto(id: "p10"),
            makePhoto(id: "p11"),
            makePhoto(id: "p12")
        ]

        let repository = ControlledTodayRepository(pages: [pageOne, pageTwo])
        let viewModel = TodayViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()
        await viewModel.load()

        let organicItems = viewModel.items.filter { !$0.isSponsored }

        #expect(organicItems.map(\.photo.id.rawValue) == (1...12).map { "p\($0)" })

        #expect(await repository.organicRequests == [1, 2])
        #expect(viewModel.state == .ready)

        for (index, item) in organicItems.enumerated() {
            #expect(isFullBleed(viewModel.photoStyle(for: item)) == index.isMultiple(of: 4))
        }
    }

    @Test("Retry loads the same organic page after failure")
    @MainActor
    func retryLoadsFailedPageAgain() async {
        let photos = [
            makePhoto(id: "p1"),
            makePhoto(id: "p2")
        ]

        let repository = RetryingOrganicRepository(photos: photos)
        let viewModel = TodayViewModel(repository: repository)

        await viewModel.load()

        guard case .failed = viewModel.state else {
            Issue.record("Expected the initial organic request to fail.")
            return
        }

        #expect(viewModel.items.isEmpty)

        await viewModel.retry()

        #expect(viewModel.state == .ready)
        #expect(viewModel.items.map(\.photo.id.rawValue) == ["p1", "p2"])
        #expect(await repository.requestedPages == [1, 1])
    }

    @Test("Organic pagination continues while sponsored loading is blocked")
    @MainActor
    func sponsoredLoadingDoesNotBlockOrganicPagination() async {
        let pageOne = (1...10).map { makePhoto(id: "p\($0)") }
        let pageTwo = (11...20).map { makePhoto(id: "p\($0)") }

        let repository = ControlledTodayRepository(pages: [pageOne, pageTwo])
        let viewModel = TodayViewModel(
            repository: repository,
            sponsoredConfiguration: .init(
                targetCoverage: 1,
                lowWatermark: 0,
                requestBatchSize: 1,
                maximumRequestsPerEpisode: 1
            )
        )

        viewModel.setSponsoredLoadingActive(true)

        await repository.waitForSponsoredRequest(1)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.state == .ready)
        #expect(viewModel.items.count == 20)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })
        #expect(await repository.organicRequests == [1, 2])
        #expect(await repository.sponsoredRequestCount == 1)

        viewModel.setSponsoredLoadingActive(false)
        await repository.finishAllSponsored()
    }

    @Test("Available sponsored content is inserted below the visible feed anchor")
    @MainActor
    func insertsSponsoredContentBelowVisibleAnchor() async throws {
        let organicPhotos = (1...10).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(pages: [organicPhotos])
        let viewModel = TodayViewModel(
            repository: repository,
            sponsoredConfiguration: .init(
                targetCoverage: 1,
                lowWatermark: 0,
                requestBatchSize: 1,
                maximumRequestsPerEpisode: 1
            )
        )

        await viewModel.load()

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[1].id))

        await repository.finishSponsored([
            makePhoto(id: "sp1")
        ])

        try await waitFor {
            viewModel.items.contains(where: \.isSponsored)
        }

        let visibleIndex = viewModel.items.firstIndex {
            $0.id == .organic(organicPhotos[1].id)
        }

        let requiredVisibleIndex = try #require(visibleIndex)
        let possibleSponsoredIndex = viewModel.items.firstIndex(where: \.isSponsored)
        let sponsoredIndex = try #require(possibleSponsoredIndex)

        #expect(sponsoredIndex > requiredVisibleIndex)

        #expect(
            viewModel.items
                .filter(\.isSponsored)
                .allSatisfy {
                    !isFullBleed(viewModel.photoStyle(for: $0))
                }
        )

        viewModel.setSponsoredLoadingActive(false)
    }

    @Test("Late sponsored content stays beyond the furthest reached feed position")
    @MainActor
    func lateSponsoredContentUsesFurthestReachedPosition() async throws {
        let organicPhotos = (1...10).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(
            pages: [organicPhotos]
        )

        let viewModel = TodayViewModel(
            repository: repository,
            insertionPolicy: SponsoredInsertionPolicy(
                organicItemsBetweenSponsored: 3
            ),
            sponsoredConfiguration: .init(
                targetCoverage: 1,
                lowWatermark: 0,
                requestBatchSize: 1,
                maximumRequestsPerEpisode: 1
            )
        )

        await viewModel.load()

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)


        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[3].id))
        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        await repository.finishSponsored([
            makePhoto(id: "sp1")
        ])

        try await waitFor {
            viewModel.items.contains(where: \.isSponsored)
        }

        let possibleFurthestReachedIndex = viewModel.items.firstIndex {
            $0.id == .organic(organicPhotos[3].id)
        }
        let furthestReachedIndex = try #require(possibleFurthestReachedIndex)

        let possibleSponsoredIndex = viewModel.items.firstIndex(where: \.isSponsored)
        let sponsoredIndex = try #require(possibleSponsoredIndex)

        #expect(sponsoredIndex > furthestReachedIndex)

        viewModel.setSponsoredLoadingActive(false)
    }

    @Test("Sponsored candidates duplicating organic photos are ignored")
    @MainActor
    func ignoresSponsoredCandidatesDuplicatingOrganicPhotos() async throws {
        let organicPhotos = (1...4).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(pages: [organicPhotos])
        let viewModel = TodayViewModel(
            repository: repository,
            sponsoredConfiguration: .init(
                targetCoverage: 1,
                lowWatermark: 0,
                requestBatchSize: 1,
                maximumRequestsPerEpisode: 1
            )
        )

        await viewModel.load()

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)

        await repository.finishSponsored([
            organicPhotos[0],
            makePhoto(id: "sp1")
        ])

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        try await waitFor {
            viewModel.items.contains(where: \.isSponsored)
        }

        let sponsoredIDs: [String?] = viewModel.items.compactMap { item in
            guard case .sponsored(let photo) = item else {
                return nil
            }

            return photo.id.rawValue
        }

        #expect(sponsoredIDs == ["sp1"])

        let allIDs = viewModel.items.map(\.photo.id)
        #expect(Set(allIDs).count == allIDs.count)

        viewModel.setSponsoredLoadingActive(false)
    }

    @Test("Sponsored buffer replenishes when it reaches the low watermark")
    @MainActor
    func replenishesSponsoredBufferAtLowWatermark() async throws {
        let organicPhotos = (1...6).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(pages: [organicPhotos])
        let viewModel = TodayViewModel(
            repository: repository,
            insertionPolicy: SponsoredInsertionPolicy(
                organicItemsBetweenSponsored: 4
            ),
            sponsoredConfiguration: .init(
                targetCoverage: 3,
                lowWatermark: 1,
                requestBatchSize: 3,
                maximumRequestsPerEpisode: 1
            )
        )

        await viewModel.load()

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        await repository.finishSponsored([
            makePhoto(id: "sp1"),
            makePhoto(id: "sp2"),
            makePhoto(id: "sp3")
        ])

        try await waitFor {
            viewModel.items.filter(\.isSponsored).count == 2
        }

        #expect(await repository.sponsoredRequestCount == 1)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[1].id))

        await repository.waitForSponsoredRequest(2)

        #expect(await repository.sponsoredRequestCount == 2)

        await repository.finishSponsored([
            makePhoto(id: "sp4"),
            makePhoto(id: "sp5")
        ])

        viewModel.setSponsoredLoadingActive(false)
    }

    @Test("Sponsored failure does not fail the organic feed")
    @MainActor
    func sponsoredFailureDoesNotFailOrganicFeed() async {
        let organicPhotos = (1...10).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(pages: [organicPhotos])
        let viewModel = TodayViewModel(
            repository: repository,
            sponsoredConfiguration: .init(
                targetCoverage: 1,
                lowWatermark: 0,
                requestBatchSize: 1,
                maximumRequestsPerEpisode: 1
            )
        )

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)

        await repository.failSponsored(URLError(.timedOut))

        await viewModel.load()

        #expect(viewModel.state == .ready)
        #expect(viewModel.items.count == 10)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })

        viewModel.setSponsoredLoadingActive(false)
    }

    @Test("Reactivation discards a cancelled sponsored response")
    @MainActor
    func reactivationDiscardsCancelledSponsoredResponse() async throws {
        let organicPhotos = (1...10).map {
            makePhoto(id: "p\($0)")
        }

        let repository = ControlledTodayRepository(pages: [organicPhotos])
        let viewModel = TodayViewModel(
            repository: repository,
            sponsoredConfiguration: .init(
                targetCoverage: 3,
                lowWatermark: 1,
                requestBatchSize: 3,
                maximumRequestsPerEpisode: 1
            )
        )

        await viewModel.load()

        viewModel.setSponsoredLoadingActive(true)
        await repository.waitForSponsoredRequest(1)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        viewModel.setSponsoredLoadingActive(false)
        viewModel.setSponsoredLoadingActive(true)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        await repository.finishSponsored([
            makePhoto(id: "stale")
        ])

        await repository.waitForSponsoredRequest(2)

        await repository.finishSponsored([
            makePhoto(id: "fresh1"),
            makePhoto(id: "fresh2"),
            makePhoto(id: "fresh3")
        ])

        try await waitFor {
            viewModel.items.filter(\.isSponsored).count == 3
        }

        #expect(
            !viewModel.items.contains {
                $0.photo.id.rawValue == "stale"
            }
        )

        #expect(
            viewModel.items
                .filter(\.isSponsored)
                .map(\.photo.id.rawValue)
            == ["fresh1", "fresh2", "fresh3"]
        )

        viewModel.setSponsoredLoadingActive(false)
    }
}

@MainActor
private func isFullBleed(_ style: PhotoCardStyle) -> Bool {
    if case .fullBleed = style {
        return true
    }

    return false
}

@MainActor
private func waitFor(_ condition: @escaping @MainActor () -> Bool) async throws {
    while true {
        try Task.checkCancellation()

        let stream = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let isSatisfied = withObservationTracking({ condition() }, onChange: {
            stream.continuation.yield()
        })

        if isSatisfied {
            stream.continuation.finish()
            return
        }

        var iterator = stream.stream.makeAsyncIterator()
        _ = await iterator.next()

        stream.continuation.finish()
    }
}

private actor ControlledTodayRepository: PhotosRepository {

    private let pages: [[Photo]]

    private let sponsoredRequestEvents: AsyncStream<Int>
    private let sponsoredRequestEventContinuation: AsyncStream<Int>.Continuation

    private(set) var organicRequests: [Int] = []
    private(set) var sponsoredRequestCount = 0

    private var sponsoredWaiters: [CheckedContinuation<[Photo], Error>] = []

    init(pages: [[Photo]]) {
        self.pages = pages

        let stream = AsyncStream<Int>.makeStream(bufferingPolicy: .unbounded)

        sponsoredRequestEvents = stream.stream
        sponsoredRequestEventContinuation = stream.continuation
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        organicRequests.append(page)

        guard pages.indices.contains(page - 1) else {
            return []
        }

        return Array(
            pages[page - 1].prefix(perPage)
        )
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        sponsoredRequestCount += 1
        sponsoredRequestEventContinuation.yield(sponsoredRequestCount)

        return try await withCheckedThrowingContinuation {
            continuation in

            sponsoredWaiters.append(continuation)
        }
    }

    func waitForSponsoredRequest(_ expectedCount: Int) async {
        guard sponsoredRequestCount < expectedCount else {
            return
        }

        var iterator =
        sponsoredRequestEvents.makeAsyncIterator()

        while let requestCount = await iterator.next() {
            if requestCount >= expectedCount {
                return
            }
        }
    }

    func finishSponsored(_ photos: [Photo]) {
        guard !sponsoredWaiters.isEmpty else {
            Issue.record(
                "Attempted to finish a sponsored request that was not pending."
            )
            return
        }

        sponsoredWaiters
            .removeFirst()
            .resume(returning: photos)
    }

    func failSponsored(_ error: URLError) {
        guard !sponsoredWaiters.isEmpty else {
            Issue.record("Attempted to fail a sponsored request that was not pending.")
            return
        }

        sponsoredWaiters
            .removeFirst()
            .resume(throwing: error)
    }

    func finishAllSponsored() {
        while !sponsoredWaiters.isEmpty {
            sponsoredWaiters
                .removeFirst()
                .resume(returning: [])
        }
    }
}

private actor RetryingOrganicRepository: PhotosRepository {

    private let photosToReturn: [Photo]

    private(set) var requestedPages: [Int] = []
    private var attempt = 0

    init(photos: [Photo]) {
        photosToReturn = photos
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        requestedPages.append(page)
        attempt += 1

        if attempt == 1 {
            throw URLError(.timedOut)
        }

        return Array(
            photosToReturn.prefix(perPage)
        )
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        []
    }
}

private nonisolated func makePhoto(id: String) -> Photo {
    let imageURL = URL(string: "https://images.unsplash.com/\(id)")!

    return Photo(
        id: .init(rawValue: id),
        width: 1200,
        height: 1600,
        colorHex: nil,
        description: id,
        imageURLs: .init(
            full: imageURL,
            regular: imageURL,
            small: imageURL,
            thumbnail: imageURL
        ),
        user: User(
            id: .init(rawValue: "user-\(id)"),
            username: "user-\(id)",
            name: "User \(id)",
            avatarURL: imageURL,
            webpageURL: URL(
                string: "https://unsplash.com/@user-\(id)"
            )!
        ),
        webpageURL: URL(
            string: "https://unsplash.com/photos/\(id)"
        )!
    )
}
