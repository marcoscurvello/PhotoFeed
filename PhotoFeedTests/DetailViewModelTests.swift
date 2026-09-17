//
//  DetailViewModelTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Detail view model", .timeLimit(.minutes(1)))
struct DetailViewModelTests {

    @Test("User photos and statistics load successfully")
    @MainActor
    func loadsDetailContent() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .success(fixture.userPhotos),
            statisticsResult: .success(fixture.statistics)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("User photos and statistics start concurrently")
    @MainActor
    func loadsDetailContentConcurrently() async throws {
        let fixture = try await makeFixture()
        let gate = AsyncGate()

        let repository = TestPhotoDetailRepository(
            userPhotosResult: .success(fixture.userPhotos),
            statisticsResult: .success(fixture.statistics),
            userPhotosGate: gate,
            statisticsGate: gate
        )

        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        let loadTask = Task {
            await viewModel.load()
        }

        await repository.waitUntilBothRequestsStarted()

        let counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 1)

        await gate.open()
        await loadTask.value

        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("Statistics failure does not prevent user photos from loading")
    @MainActor
    func statisticsFailureDoesNotFailUserPhotos() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .success(fixture.userPhotos),
            statisticsResult: .failure(.expected)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
        #expect(viewModel.statisticsState == .failed(.unknown))
    }

    @Test("User photos failure does not prevent statistics from loading")
    @MainActor
    func userPhotosFailureDoesNotFailStatistics() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .failure(.expected),
            statisticsResult: .success(fixture.statistics)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(viewModel.userPhotosState == .failed(.unknown))
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("Retrying statistics does not reload user photos")
    @MainActor
    func retryStatisticsOnlyReloadsStatistics() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .success(fixture.userPhotos),
            statisticsResult: .failure(.expected)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        var counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 1)
        #expect(viewModel.statisticsState == .failed(.unknown))

        await repository.setStatisticsResult(.success(fixture.statistics))
        await viewModel.retryStatistics()

        counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 2)
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("Retrying user photos does not reload statistics")
    @MainActor
    func retryUserPhotosOnlyReloadsUserPhotos() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .failure(.expected),
            statisticsResult: .success(fixture.statistics)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        var counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 1)
        #expect(viewModel.userPhotosState == .failed(.unknown))

        await repository.setUserPhotosResult(.success(fixture.userPhotos))
        await viewModel.retryUserPhotos()

        counts = await repository.callCounts()

        #expect(counts.userPhotos == 2)
        #expect(counts.statistics == 1)
        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
    }

    @Test("Retrying statistics retains its failure while the request is in flight")
    @MainActor
    func retryShowsRetryingStateUntilStatisticsCompletes() async throws {
        let fixture = try await makeFixture()
        let repository = SuspendedRetryingStatisticsRepository(
            userPhotos: fixture.userPhotos,
            statistics: fixture.statistics
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()
        #expect(viewModel.statisticsState == .failed(.offline))

        let retryTask = Task {
            await viewModel.retryStatistics()
        }

        await repository.waitUntilRetryStarted()
        #expect(viewModel.statisticsState == .retrying(.offline))

        await repository.completeRetry()
        await retryTask.value

        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("The selected photo is excluded before user photos are stored")
    @MainActor
    func filtersSelectedPhotoBeforeStoringUserPhotos() async throws {
        let fixture = try await makeFixture()
        let repository = TestPhotoDetailRepository(
            userPhotosResult: .success([fixture.photo] + fixture.userPhotos),
            statisticsResult: .success(fixture.statistics)
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
    }

    @Test("Cancelled resources return to idle and retry independently")
    @MainActor
    func retriesOnlyTheResourceCancelledByTheSystem() async throws {
        let fixture = try await makeFixture()
        let repository = CancellationThenSuccessDetailRepository(
            userPhotos: fixture.userPhotos,
            statistics: fixture.statistics
        )
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(viewModel.userPhotosState == .idle)
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))

        await viewModel.load()

        let counts = await repository.callCounts()

        #expect(counts.userPhotos == 2)
        #expect(counts.statistics == 1)
        #expect(
            viewModel.userPhotosState
            == .loaded(fixture.userPhotos.filter { $0.id != fixture.photo.id })
        )
        #expect(viewModel.statisticsState == .loaded(fixture.statistics))
    }

    @Test("Retry actions do not repeat unavailable resource requests")
    @MainActor
    func retryRejectsUnavailableFailures() async throws {
        let fixture = try await makeFixture()
        let repository = UnavailableDetailRepository()
        let viewModel = DetailViewModel(photo: fixture.photo, repository: repository)

        await viewModel.load()

        #expect(viewModel.userPhotosState == .failed(.accessDenied))
        #expect(viewModel.statisticsState == .failed(.accessDenied))

        await viewModel.retryUserPhotos()
        await viewModel.retryStatistics()

        let counts = await repository.callCounts()
        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 1)
    }
}

// MARK: - Fixtures

private extension DetailViewModelTests {

    struct Fixture {
        let photo: Photo
        let userPhotos: [Photo]
        let statistics: PhotoStatistics
    }

    func makeFixture() async throws -> Fixture {
        let repository = FixturePhotosRepository()
        let photoPage = try await repository.photos(page: 1, perPage: 10)
        let photo = try #require(photoPage.photos.first)

        async let userPhotos = repository.userPhotos(username: photo.user.username, page: 1, perPage: 10)
        async let statistics = repository.statistics(photoID: photo.id)

        return try await Fixture(
            photo: photo,
            userPhotos: userPhotos,
            statistics: statistics
        )
    }

}

// MARK: - Test repository

private actor TestPhotoDetailRepository: PhotoDetailRepository {

    enum TestError: Error {
        case expected
    }

    private var userPhotosResult: Result<[Photo], TestError>
    private var statisticsResult: Result<PhotoStatistics, TestError>

    private let userPhotosGate: AsyncGate?
    private let statisticsGate: AsyncGate?

    private var userPhotosCallCount = 0
    private var statisticsCallCount = 0
    private let bothRequestsStarted = AsyncStream<Void>.makeStream()

    init(
        userPhotosResult: Result<[Photo], TestError>,
        statisticsResult: Result<PhotoStatistics, TestError>,
        userPhotosGate: AsyncGate? = nil,
        statisticsGate: AsyncGate? = nil
    ) {
        self.userPhotosResult = userPhotosResult
        self.statisticsResult = statisticsResult
        self.userPhotosGate = userPhotosGate
        self.statisticsGate = statisticsGate
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        userPhotosCallCount += 1
        resumeBothRequestsStartedWaitersIfReady()

        if let userPhotosGate {
            await userPhotosGate.wait()
        }

        return try userPhotosResult.get()
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statisticsCallCount += 1
        resumeBothRequestsStartedWaitersIfReady()

        if let statisticsGate {
            await statisticsGate.wait()
        }

        return try statisticsResult.get()
    }

    func setUserPhotosResult(_ result: Result<[Photo], TestError>) {
        userPhotosResult = result
    }

    func setStatisticsResult(_ result: Result<PhotoStatistics, TestError>) {
        statisticsResult = result
    }

    func callCounts() -> (userPhotos: Int, statistics: Int) {
        (userPhotosCallCount, statisticsCallCount)
    }

    func waitUntilBothRequestsStarted() async {
        var iterator = bothRequestsStarted.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    private func resumeBothRequestsStartedWaitersIfReady() {
        guard userPhotosCallCount >= 1, statisticsCallCount >= 1 else {
            return
        }

        bothRequestsStarted.continuation.yield(())
        bothRequestsStarted.continuation.finish()
    }
}

private actor CancellationThenSuccessDetailRepository: PhotoDetailRepository {

    private let userPhotosToReturn: [Photo]
    private let statisticsToReturn: PhotoStatistics

    private var userPhotosCallCount = 0
    private var statisticsCallCount = 0

    init(userPhotos: [Photo], statistics: PhotoStatistics) {
        userPhotosToReturn = userPhotos
        statisticsToReturn = statistics
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        userPhotosCallCount += 1

        if userPhotosCallCount == 1 {
            throw URLError(.cancelled)
        }

        return userPhotosToReturn
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statisticsCallCount += 1
        return statisticsToReturn
    }

    func callCounts() -> (userPhotos: Int, statistics: Int) {
        (userPhotosCallCount, statisticsCallCount)
    }
}

private actor UnavailableDetailRepository: PhotoDetailRepository {

    private var userPhotosCallCount = 0
    private var statisticsCallCount = 0

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        userPhotosCallCount += 1
        throw ResourceLoadFailure.accessDenied
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statisticsCallCount += 1
        throw ResourceLoadFailure.accessDenied
    }

    func callCounts() -> (userPhotos: Int, statistics: Int) {
        (userPhotosCallCount, statisticsCallCount)
    }
}

private actor SuspendedRetryingStatisticsRepository: PhotoDetailRepository {

    private let userPhotosToReturn: [Photo]
    private let statisticsToReturn: PhotoStatistics
    private var statisticsAttempt = 0
    private let retryStarted = AsyncGate()
    private let retryCompletion = AsyncGate()

    init(userPhotos: [Photo], statistics: PhotoStatistics) {
        userPhotosToReturn = userPhotos
        statisticsToReturn = statistics
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        userPhotosToReturn
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statisticsAttempt += 1

        guard statisticsAttempt > 1 else {
            throw ResourceLoadFailure.offline
        }

        await retryStarted.open()
        await retryCompletion.wait()

        return statisticsToReturn
    }

    func waitUntilRetryStarted() async {
        await retryStarted.wait()
    }

    func completeRetry() async {
        await retryCompletion.open()
    }
}

// MARK: - Async gate

private actor AsyncGate {

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
        guard !isOpen else {
            return
        }

        isOpen = true

        for waiter in waiters {
            waiter.resume()
        }

        waiters.removeAll()
    }
}
