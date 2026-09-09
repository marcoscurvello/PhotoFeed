//
//  DetailViewModelTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("Detail view model")
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

        #expect(viewModel.userPhotos == fixture.userPhotos)
        #expect(viewModel.statistics == fixture.statistics)
        #expect(viewModel.userPhotosErrorMessage == nil)
        #expect(viewModel.statisticsErrorMessage == nil)
        #expect(viewModel.isLoadingUserPhotos == false)
        #expect(viewModel.isLoadingStatistics == false)
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

        await waitForBothRequests(toStartIn: repository)

        let counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 1)

        await gate.open()
        await loadTask.value

        #expect(viewModel.userPhotos == fixture.userPhotos)
        #expect(viewModel.statistics == fixture.statistics)
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

        #expect(viewModel.userPhotos == fixture.userPhotos)
        #expect(viewModel.userPhotosErrorMessage == nil)
        #expect(viewModel.statistics == nil)
        #expect(viewModel.statisticsErrorMessage != nil)
        #expect(viewModel.isLoadingUserPhotos == false)
        #expect(viewModel.isLoadingStatistics == false)
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

        #expect(viewModel.userPhotos.isEmpty)
        #expect(viewModel.userPhotosErrorMessage != nil)
        #expect(viewModel.statistics == fixture.statistics)
        #expect(viewModel.statisticsErrorMessage == nil)
        #expect(viewModel.isLoadingUserPhotos == false)
        #expect(viewModel.isLoadingStatistics == false)
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
        #expect(viewModel.statistics == nil)

        await repository.setStatisticsResult(.success(fixture.statistics))
        await viewModel.retryStatistics()

        counts = await repository.callCounts()

        #expect(counts.userPhotos == 1)
        #expect(counts.statistics == 2)
        #expect(viewModel.statistics == fixture.statistics)
        #expect(viewModel.statisticsErrorMessage == nil)
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
        #expect(viewModel.userPhotos.isEmpty)

        await repository.setUserPhotosResult(.success(fixture.userPhotos))
        await viewModel.retryUserPhotos()

        counts = await repository.callCounts()

        #expect(counts.userPhotos == 2)
        #expect(counts.statistics == 1)
        #expect(viewModel.userPhotos == fixture.userPhotos)
        #expect(viewModel.userPhotosErrorMessage == nil)
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
        let photos = try await repository.photos(page: 1, perPage: 10)
        let photo = try #require(photos.first)

        async let userPhotos = repository.userPhotos(username: photo.user.username, page: 1, perPage: 10)
        async let statistics = repository.statistics(photoID: photo.id)

        return try await Fixture(
            photo: photo,
            userPhotos: userPhotos,
            statistics: statistics
        )
    }

    func waitForBothRequests(toStartIn repository: TestPhotoDetailRepository) async {
        for _ in 0..<1_000 {
            let counts = await repository.callCounts()

            if counts.userPhotos == 1 && counts.statistics == 1 {
                return
            }

            await Task.yield()
        }
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

        if let userPhotosGate {
            await userPhotosGate.wait()
        }

        return try userPhotosResult.get()
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statisticsCallCount += 1

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
