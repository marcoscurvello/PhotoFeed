//
//  DebugFailureInjectionTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 17/09/2026.
//

#if DEBUG
import Foundation
import Testing
@testable import PhotoFeed

@Suite("Debug failure injection")
struct DebugFailureInjectionTests {

    @Test("Configuration parses a rate-limited page failure")
    func parsesConfigurationAndMapsItsFailure() {
        let configuration = DebugFailureConfiguration(
            environment: [
                "PHOTOFEED_FAILURE_TARGETS": "today-page-2",
                "PHOTOFEED_FAILURE_KIND": "rate-limited",
                "PHOTOFEED_FAILURE_MODE": "once",
                "PHOTOFEED_FAILURE_DELAY": "1.5",
                "PHOTOFEED_RETRY_AFTER": "10"
            ]
        )
        let now = Date(timeIntervalSince1970: 100)

        #expect(configuration?.targets == [.todayPage(2)])
        #expect(configuration?.kind == .rateLimited)
        #expect(configuration?.mode == .once)
        #expect(configuration?.delay == .milliseconds(1_500))
        #expect(
            configuration?.failure(now: now)
                == .rateLimited(.init(limit: 50, remaining: 0, retryAfter: now.addingTimeInterval(10)))
        )
    }

    @Test("Configuration parses multiple targets and ignores duplicates")
    func parsesMultipleTargets() {
        let configuration = DebugFailureConfiguration(
            environment: [
                "PHOTOFEED_FAILURE_TARGETS": "statistics, today-page-2,statistics",
                "PHOTOFEED_FAILURE_KIND": "rate-limited"
            ]
        )

        #expect(configuration?.targets == [.statistics, .todayPage(2)])
    }

    @Test("Configuration can schedule a rate-limit retry at the next UTC hour")
    func schedulesRateLimitRetryAtNextHour() {
        let configuration = DebugFailureConfiguration(
            environment: [
                "PHOTOFEED_FAILURE_TARGETS": "today-page-2",
                "PHOTOFEED_FAILURE_KIND": "rate-limited",
                "PHOTOFEED_RETRY_AFTER": "next-hour"
            ]
        )
        let responseDate = Date(timeIntervalSince1970: 1_789_729_148)
        let expectedReset = Date(timeIntervalSince1970: 1_789_729_200)

        #expect(
            configuration?.failure(now: responseDate)
                == .rateLimited(.init(limit: 50, remaining: 0, retryAfter: expectedReset))
        )
    }

    @Test("Configuration maps every failure kind")
    func mapsEveryFailureKind() {
        let expectedFailures: [(String, ResourceLoadFailure)] = [
            ("offline", .offline),
            ("timed-out", .timedOut),
            ("rate-limited", .rateLimited(.init(limit: 50, remaining: 0, retryAfter: nil))),
            ("service-unavailable", .serviceUnavailable(retryAfter: nil)),
            ("access-denied", .accessDenied),
            ("not-found", .notFound),
            ("invalid-response", .invalidResponse),
            ("unknown", .unknown)
        ]

        for (kind, expectedFailure) in expectedFailures {
            let configuration = DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "sponsored",
                    "PHOTOFEED_FAILURE_KIND": kind
                ]
            )

            #expect(configuration?.failure() == expectedFailure)
        }
    }

    @Test("Configuration rejects malformed values and defaults its optional values")
    func validatesConfiguration() {
        #expect(
            DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "today-page-0",
                    "PHOTOFEED_FAILURE_KIND": "offline"
                ]
            ) == nil
        )
        #expect(
            DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "statistics,unknown",
                    "PHOTOFEED_FAILURE_KIND": "offline"
                ]
            ) == nil
        )
        #expect(
            DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "statistics,",
                    "PHOTOFEED_FAILURE_KIND": "offline"
                ]
            ) == nil
        )
        #expect(
            DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "sponsored",
                    "PHOTOFEED_FAILURE_KIND": "offline",
                    "PHOTOFEED_FAILURE_DELAY": "-1"
                ]
            ) == nil
        )
        #expect(
            DebugFailureConfiguration(
                environment: [
                    "PHOTOFEED_FAILURE_TARGETS": "statistics",
                    "PHOTOFEED_FAILURE_KIND": "service-unavailable",
                    "PHOTOFEED_RETRY_AFTER": "next-hour"
                ]
            ) == nil
        )

        let configuration = DebugFailureConfiguration(
            environment: [
                "PHOTOFEED_FAILURE_TARGETS": "statistics",
                "PHOTOFEED_FAILURE_KIND": "service-unavailable"
            ]
        )

        #expect(configuration?.targets == [.statistics])
        #expect(configuration?.mode == .always)
        #expect(configuration?.delay == .zero)
        #expect(configuration?.failure() == .serviceUnavailable(retryAfter: nil))
    }

    @Test("Nonmatching operations delegate to the wrapped repository")
    func delegatesNonmatchingOperations() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "statistics",
            kind: "offline",
            base: repository
        )

        let page = try await injector.photos(page: 1, perPage: 10)

        #expect(page.photos == [testPhoto])
        #expect(await repository.callCounts().photos == 1)
    }

    @Test("Today page injection only fails the configured page")
    func injectsConfiguredTodayPage() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "today-page-2",
            kind: "rate-limited",
            base: repository
        )

        _ = try await injector.photos(page: 1, perPage: 10)

        await #expect(
            throws: ResourceLoadFailure.rateLimited(
                .init(limit: 50, remaining: 0, retryAfter: nil)
            )
        ) {
            try await injector.photos(page: 2, perPage: 10)
        }

        #expect(await repository.callCounts().photos == 1)
    }

    @Test("Once mode fails the first matching operation and delegates the retry")
    func injectsFailureOnce() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "sponsored",
            kind: "offline",
            mode: "once",
            base: repository
        )

        await #expect(throws: ResourceLoadFailure.offline) {
            try await injector.sponsoredPhotos(count: 1)
        }

        let photos = try await injector.sponsoredPhotos(count: 1)

        #expect(photos == [testPhoto])
        #expect(await repository.callCounts().sponsored == 1)
    }

    @Test("Once mode fails once for each configured target")
    func injectsFailureOncePerTarget() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "statistics,user-photos",
            kind: "offline",
            mode: "once",
            base: repository
        )

        await #expect(throws: ResourceLoadFailure.offline) {
            try await injector.statistics(photoID: testPhoto.id)
        }
        await #expect(throws: ResourceLoadFailure.offline) {
            try await injector.userPhotos(username: "user", page: 1, perPage: 10)
        }

        _ = try await injector.statistics(photoID: testPhoto.id)
        _ = try await injector.userPhotos(username: "user", page: 1, perPage: 10)

        let counts = await repository.callCounts()
        #expect(counts.statistics == 1)
        #expect(counts.userPhotos == 1)
    }

    @Test("Always mode fails every matching operation without delegation")
    func injectsFailureEveryTime() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "user-photos",
            kind: "not-found",
            base: repository
        )

        await #expect(throws: ResourceLoadFailure.notFound) {
            try await injector.userPhotos(username: "user", page: 1, perPage: 10)
        }
        await #expect(throws: ResourceLoadFailure.notFound) {
            try await injector.userPhotos(username: "user", page: 1, perPage: 10)
        }

        #expect(await repository.callCounts().userPhotos == 0)
    }

    @Test("Statistics target intercepts statistics without calling the base")
    func injectsStatisticsFailure() async throws {
        let repository = RecordingPhotoRepository()
        let injector = try makeInjector(
            targets: "statistics",
            kind: "service-unavailable",
            base: repository
        )

        await #expect(throws: ResourceLoadFailure.serviceUnavailable(retryAfter: nil)) {
            try await injector.statistics(photoID: testPhoto.id)
        }

        #expect(await repository.callCounts().statistics == 0)
    }

    private func makeInjector<Base>(
        targets: String,
        kind: String,
        mode: String? = nil,
        base: Base
    ) throws -> FaultInjectingPhotoRepository<Base>
    where Base: PhotosRepository & PhotoDetailRepository {
        var environment = [
            "PHOTOFEED_FAILURE_TARGETS": targets,
            "PHOTOFEED_FAILURE_KIND": kind
        ]
        environment["PHOTOFEED_FAILURE_MODE"] = mode

        let configuration = try #require(
            DebugFailureConfiguration(environment: environment)
        )
        return FaultInjectingPhotoRepository(base: base, configuration: configuration)
    }
}

private actor RecordingPhotoRepository: PhotosRepository, PhotoDetailRepository {

    struct CallCounts: Sendable {
        var photos = 0
        var sponsored = 0
        var userPhotos = 0
        var statistics = 0
    }

    private var counts = CallCounts()

    func photos(page: Int, perPage: Int) async throws -> PhotoPage {
        counts.photos += 1
        return .init(photos: [testPhoto], page: page, perPage: perPage, total: 1)
    }

    func sponsoredPhotos(count: Int) async throws -> [Photo] {
        counts.sponsored += 1
        return [testPhoto]
    }

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        counts.userPhotos += 1
        return [testPhoto]
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        counts.statistics += 1
        return .init(
            views: .init(total: 1, change: 0, periodDays: 1),
            likes: nil,
            downloads: .init(total: 1, change: 0, periodDays: 1)
        )
    }

    func callCounts() -> CallCounts {
        counts
    }
}

private let testPhoto = Photo(
    id: .init(rawValue: "test-photo"),
    width: 100,
    height: 100,
    colorHex: nil,
    description: nil,
    imageURLs: .init(
        raw: URL(string: "https://example.com/raw")!,
        full: URL(string: "https://example.com/full")!,
        regular: URL(string: "https://example.com/regular")!,
        small: URL(string: "https://example.com/small")!,
        thumbnail: URL(string: "https://example.com/thumbnail")!
    ),
    user: .init(
        id: .init(rawValue: "test-user"),
        username: "test-user",
        name: "Test User",
        avatarURL: URL(string: "https://example.com/avatar")!,
        webpageURL: URL(string: "https://example.com/user")!
    ),
    webpageURL: URL(string: "https://example.com/photo")!
)
#endif
