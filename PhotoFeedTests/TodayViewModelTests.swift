//
//  TodayViewModelTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Today view model")
struct TodayViewModelTests {

    @Test("Available sponsored photos follow the expected cadence once a visible anchor is known")
    @MainActor
    func insertsSponsoredPhotosAtExpectedPositions() async {
        let organicPhotos = (1...10).map { makePhoto(id: "p\($0)") }
        let sponsoredPhotos = (1...3).map { makePhoto(id: "sp\($0)") }

        let repository = TestPhotosRepository(
            organicPhotos: organicPhotos,
            sponsoredPhotos: sponsoredPhotos
        )

        let viewModel = TodayViewModel(
            repository: repository,
            insertionPolicy: SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3),
            sponsoredRequestCount: 3
        )

        await viewModel.load()

        #expect(viewModel.items.count == 10)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        let identifiers = viewModel.items.map { item in
            switch item {
            case .organic(let photo):
                return "P:\(photo.id.rawValue)"
            case .sponsored(let photo):
                return "SP:\(photo.id.rawValue)"
            }
        }

        #expect(
            identifiers == [
                "P:p1",
                "SP:sp1",
                "P:p2",
                "P:p3",
                "P:p4",
                "SP:sp2",
                "P:p5",
                "P:p6",
                "P:p7",
                "SP:sp3",
                "P:p8",
                "P:p9",
                "P:p10"
            ]
        )
    }

    @Test("Sponsored photos already present in the organic feed are ignored")
    @MainActor
    func ignoresSponsoredPhotosDuplicatingOrganicPhotos() async {
        let organicPhotos = (1...4).map { makePhoto(id: "p\($0)") }

        let repository = TestPhotosRepository(
            organicPhotos: organicPhotos,
            sponsoredPhotos: [
                makePhoto(id: "p1"),
                makePhoto(id: "sp1")
            ]
        )

        let viewModel = TodayViewModel(
            repository: repository,
            insertionPolicy: SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3),
            sponsoredRequestCount: 2
        )

        await viewModel.load()
        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        let sponsoredIDs = viewModel.items.compactMap { item -> String? in
            guard case .sponsored(let photo) = item else {
                return nil
            }

            return photo.id.rawValue
        }

        #expect(sponsoredIDs == ["sp1"])
    }

    @Test("Committed fixtures produce sponsored feed items")
    @MainActor
    func fixtureRepositoriesProduceSponsoredItems() async throws {
        let repository = FixturePhotosRepository()
        let viewModel = TodayViewModel(repository: repository)

        await viewModel.load()
        let firstItem = try #require(viewModel.items.first)
        viewModel.updateCurrentVisibleItem(firstItem.id)

        #expect(viewModel.items.count == 13)
        #expect(viewModel.items.filter(\.isSponsored).count == 3)
    }

    @Test("Organic photos are published without waiting for sponsored photos")
    @MainActor
    func publishesOrganicPhotosBeforeSponsoredPhotosFinish() async {
        let organicPhotos = (1...10).map { makePhoto(id: "p\($0)") }
        let sponsoredPhotos = (1...3).map { makePhoto(id: "sp\($0)") }
        let gate = TestGate()

        let repository = DelayedSponsoredPhotosRepository(
            organicPhotos: organicPhotos,
            sponsoredPhotos: sponsoredPhotos,
            sponsoredGate: gate
        )

        let viewModel = TodayViewModel(repository: repository, sponsoredRequestCount: 3)

        let loadTask = Task {
            await viewModel.load()
        }

        for _ in 0..<100 where viewModel.items.count != 10 {
            await Task.yield()
        }

        #expect(viewModel.items.count == 10)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })
        #expect(viewModel.isLoading == false)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[0].id))

        await gate.open()
        await loadTask.value

        #expect(viewModel.items.filter(\.isSponsored).count == 3)
    }

    @Test("Late sponsored content is inserted below the user's current position")
    @MainActor
    func insertsLateSponsoredPhotosBelowCurrentPosition() async {
        let organicPhotos = (1...10).map { makePhoto(id: "p\($0)") }
        let sponsoredPhotos = (1...3).map { makePhoto(id: "sp\($0)") }
        let gate = TestGate()

        let repository = DelayedSponsoredPhotosRepository(
            organicPhotos: organicPhotos,
            sponsoredPhotos: sponsoredPhotos,
            sponsoredGate: gate
        )

        let viewModel = TodayViewModel(
            repository: repository,
            insertionPolicy: SponsoredInsertionPolicy(organicItemsBetweenSponsored: 3),
            sponsoredRequestCount: 3
        )

        let loadTask = Task {
            await viewModel.load()
        }

        for _ in 0..<100 where viewModel.items.count != 10 {
            await Task.yield()
        }

        #expect(viewModel.items.count == 10)

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[3].id))

        await gate.open()
        await loadTask.value

        let identifiers = viewModel.items.map { item in
            switch item {
            case .organic(let photo):
                return "P:\(photo.id.rawValue)"
            case .sponsored(let photo):
                return "SP:\(photo.id.rawValue)"
            }
        }

        #expect(
            identifiers == [
                "P:p1",
                "P:p2",
                "P:p3",
                "P:p4",
                "SP:sp1",
                "P:p5",
                "P:p6",
                "P:p7",
                "SP:sp2",
                "P:p8",
                "P:p9",
                "P:p10",
                "SP:sp3"
            ]
        )
    }

    @Test("Sponsored request failure does not prevent the organic feed from loading")
    @MainActor
    func sponsoredFailureDoesNotFailTodayFeed() async {
        let organicPhotos = (1...10).map { makePhoto(id: "p\($0)") }
        let repository = FailingSponsoredPhotosRepository(organicPhotos: organicPhotos)
        let viewModel = TodayViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.items.count == 10)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("Sponsored content waits until a visible insertion anchor is known")
    @MainActor
    func sponsoredContentWaitsForVisibleAnchor() async {
        let organicPhotos = (1...10).map { makePhoto(id: "p\($0)") }
        let sponsoredPhotos = [makePhoto(id: "sp1")]

        let repository = TestPhotosRepository(
            organicPhotos: organicPhotos,
            sponsoredPhotos: sponsoredPhotos
        )

        let viewModel = TodayViewModel(repository: repository, sponsoredRequestCount: 1)

        await viewModel.load()

        #expect(viewModel.items.count == 10)
        #expect(viewModel.items.allSatisfy { !$0.isSponsored })

        viewModel.updateCurrentVisibleItem(.organic(organicPhotos[1].id))

        #expect(viewModel.items.count == 11)
        #expect(viewModel.items[2].isSponsored)
    }
}

private nonisolated struct TestPhotosRepository: PhotosRepository {
    let organicPhotos: [Photo]
    let sponsoredPhotos: [Photo]

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        Array(organicPhotos.prefix(perPage))
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        Array(sponsoredPhotos.prefix(count))
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
        imageURLs: .init(full: imageURL, regular: imageURL, small: imageURL, thumbnail: imageURL),
        user: User(
            id: .init(rawValue: "user-\(id)"),
            username: "user-\(id)",
            name: "User \(id)",
            avatarURL: imageURL,
            webpageURL: URL(string: "https://unsplash.com/@user-\(id)")!
        ),
        webpageURL: URL(string: "https://unsplash.com/photos/\(id)")!
    )
}

private actor TestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiters = waiters
        self.waiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private nonisolated struct DelayedSponsoredPhotosRepository: PhotosRepository {
    let organicPhotos: [Photo]
    let sponsoredPhotos: [Photo]
    let sponsoredGate: TestGate

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        Array(organicPhotos.prefix(perPage))
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        await sponsoredGate.wait()
        return Array(sponsoredPhotos.prefix(count))
    }
}

private nonisolated struct FailingSponsoredPhotosRepository: PhotosRepository {
    enum TestError: Error {
        case sponsoredFailed
    }

    let organicPhotos: [Photo]

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        Array(organicPhotos.prefix(perPage))
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        throw TestError.sponsoredFailed
    }
}
