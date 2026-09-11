//
//  SponsoredCoordinatorTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Sponsored coordinator", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct SponsoredCoordinatorTests {

    @Test("Returns requested unique candidates in response order")
    func returnsRequestedCandidatesInOrder() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let task = Task {
            await coordinator.loadCandidates(count: 3, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        await repository.finish([
            photo("a"),
            photo("b"),
            photo("c")
        ])

        let candidates = await task.value

        #expect(candidates.map(\.id.rawValue) == ["a", "b", "c"])
        #expect(await repository.requestCount == 1)
    }

    @Test("Filters excluded and duplicate candidates")
    func filtersExcludedAndDuplicateCandidates() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let task = Task {
            await coordinator.loadCandidates(count: 2, excluding: [photoID("excluded")])
        }

        #expect(await repository.nextRequest() == 1)

        await repository.finish([
            photo("excluded"),
            photo("a"),
            photo("a"),
            photo("b"),
            photo("c")
        ])

        let candidates = await task.value

        #expect(candidates.map(\.id.rawValue) == ["a", "b"])
        #expect(await repository.requestCount == 1)
    }

    @Test("Performs additional requests when a batch does not satisfy demand")
    func performsAdditionalRequestsWhenNeeded() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(
            repository: repository,
            configuration: .init(requestBatchSize: 2, maximumRequestsPerEpisode: 3)
        )

        let task = Task {
            await coordinator.loadCandidates(count: 3, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)
        await repository.finish([photo("a")])

        #expect(await repository.nextRequest() == 2)
        await repository.finish([
            photo("b"),
            photo("c")
        ])

        let candidates = await task.value

        #expect(candidates.map(\.id.rawValue) == ["a", "b", "c"])
        #expect(await repository.requestCount == 2)
    }

    @Test("Stops requesting once demand is satisfied")
    func stopsWhenDemandIsSatisfied() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(
            repository: repository,
            configuration: .init(requestBatchSize: 3, maximumRequestsPerEpisode: 3)
        )

        let task = Task {
            await coordinator.loadCandidates(count: 2, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        await repository.finish([
            photo("a"),
            photo("b"),
            photo("c")
        ])

        let candidates = await task.value

        #expect(candidates.map(\.id.rawValue) == ["a", "b"])
        #expect(await repository.requestCount == 1)
    }

    @Test("Limits requests to the configured episode maximum")
    func limitsRequestsPerEpisode() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(
            repository: repository,
            configuration: .init(requestBatchSize: 1, maximumRequestsPerEpisode: 2)
        )

        let task = Task {
            await coordinator.loadCandidates(count: 3, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)
        await repository.finish([photo("a")])

        #expect(await repository.nextRequest() == 2)
        await repository.finish([photo("b")])

        let candidates = await task.value

        #expect(candidates.map(\.id.rawValue) == ["a", "b"])
        #expect(await repository.requestCount == 2)

        let retryCandidates = await coordinator.loadCandidates(count: 1, excluding: [])

        #expect(retryCandidates.isEmpty)
        #expect(await repository.requestCount == 2)
    }

    @Test("Keeps only one sponsored load in flight")
    func keepsSingleInFlightLoad() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let firstTask = Task {
            await coordinator.loadCandidates(count: 1, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        let secondCandidates = await coordinator.loadCandidates(count: 1, excluding: [])

        #expect(secondCandidates.isEmpty)
        #expect(await repository.requestCount == 1)

        await repository.finish([photo("a")])

        let firstCandidates = await firstTask.value

        #expect(firstCandidates.map(\.id.rawValue) == ["a"])
    }

    @Test("Cancellation does not admit candidates returned by the cancelled request")
    func cancellationDiscardsReturnedCandidates() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let task = Task {
            await coordinator.loadCandidates(count: 3, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        task.cancel()

        await repository.finish([
            photo("stale-a"),
            photo("stale-b"),
            photo("stale-c")
        ])

        let candidates = await task.value

        #expect(candidates.isEmpty)
        #expect(await repository.requestCount == 1)
    }

    @Test("Recoverable failure enters cooldown")
    func recoverableFailureEntersCooldown() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let task = Task {
            await coordinator.loadCandidates(count: 1, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        await repository.fail(
            URLError(.timedOut)
        )

        let candidates = await task.value

        #expect(candidates.isEmpty)

        let retryCandidates = await coordinator.loadCandidates(count: 1, excluding: [])

        #expect(retryCandidates.isEmpty)
        #expect(await repository.requestCount == 1)
    }

    @Test("Nonrecoverable failure suspends subsequent loading")
    func nonrecoverableFailureSuspendsLoading() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let task = Task {
            await coordinator.loadCandidates(count: 1, excluding: [])
        }

        #expect(await repository.nextRequest() == 1)

        await repository.fail(
            URLError(.badURL)
        )

        let candidates = await task.value
        let subsequentCandidates = await coordinator.loadCandidates(
            count: 1,
            excluding: []
        )

        #expect(candidates.isEmpty)
        #expect(subsequentCandidates.isEmpty)
        #expect(await repository.requestCount == 1)
    }

    @Test("Zero demand does not start a request")
    func zeroDemandDoesNotLoad() async {
        let repository = ControlledSponsoredRepository()
        let coordinator = makeCoordinator(repository: repository)

        let candidates = await coordinator.loadCandidates(count: 0, excluding: [])

        #expect(candidates.isEmpty)
        #expect(await repository.requestCount == 0)
    }

    private func makeCoordinator(
        repository: ControlledSponsoredRepository,
        configuration: SponsoredCoordinatorConfiguration = .init()
    ) -> SponsoredCoordinator {

        SponsoredCoordinator(repository: repository, configuration: configuration)
    }

    private func photoID(_ value: String) -> Photo.ID {
        .init(rawValue: value)
    }

    private func photo(_ id: String) -> Photo {
        let url = URL(string: "https://example.com/\(id)")!

        return Photo(
            id: photoID(id),
            width: 1,
            height: 1,
            colorHex: nil,
            description: nil,
            imageURLs: .init(
                full: url,
                regular: url,
                small: url,
                thumbnail: url
            ),
            user: .init(
                id: .init(rawValue: "user"),
                username: "user",
                name: "User",
                avatarURL: url,
                webpageURL: url
            ),
            webpageURL: url
        )
    }
}

private actor ControlledSponsoredRepository: PhotosRepository {

    private let requestEvents: AsyncStream<Int>
    private let requestEventContinuation: AsyncStream<Int>.Continuation

    private(set) var requestCount = 0
    private var waiters: [CheckedContinuation<[Photo], Error>] = []

    init() {
        let stream = AsyncStream<Int>.makeStream(bufferingPolicy: .unbounded)

        requestEvents = stream.stream
        requestEventContinuation = stream.continuation
    }

    func photos(page: Int, perPage: Int) async throws -> [Photo] {
        []
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        requestCount += 1

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
            requestEventContinuation.yield(requestCount)
        }
    }

    func nextRequest() async -> Int? {
        var iterator = requestEvents.makeAsyncIterator()
        return await iterator.next()
    }

    func finish(_ photos: [Photo]) {
        guard !waiters.isEmpty else {
            Issue.record("Attempted to finish a sponsored request that was not pending.")
            return
        }

        waiters.removeFirst().resume(returning: photos)
    }

    func fail(_ error: Error) {
        guard !waiters.isEmpty else {
            Issue.record("Attempted to fail a sponsored request that was not pending.")
            return
        }

        waiters.removeFirst().resume(throwing: error)
    }
}
