//
//  DetailPreviewFixtures.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

#if DEBUG
import Foundation

@MainActor
enum DetailPreviewFixtures {
    enum RepositoryBehavior: Sendable {
        case success
        case loading
        case failure
    }

    static func makeViewModel(
        userPhotosBehavior: RepositoryBehavior = .success,
        statisticsBehavior: RepositoryBehavior = .success
    ) -> DetailViewModel {
        DetailViewModel(
            photo: TodayPreviewFixtures.photo,
            repository: PreviewPhotoDetailRepository(
                photos: TodayPreviewFixtures.photos,
                statistics: PhotoStatistics(
                    views: .init(total: 482_901, change: 14_201, periodDays: 30),
                    likes: .init(total: 8_274, change: 291, periodDays: 30),
                    downloads: .init(total: 12_482, change: 384, periodDays: 30)
                ),
                userPhotosBehavior: userPhotosBehavior,
                statisticsBehavior: statisticsBehavior
            )
        )
    }
}

private nonisolated struct PreviewPhotoDetailRepository: PhotoDetailRepository {
    let photos: [Photo]
    let statistics: PhotoStatistics
    let userPhotosBehavior: DetailPreviewFixtures.RepositoryBehavior
    let statisticsBehavior: DetailPreviewFixtures.RepositoryBehavior

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        switch userPhotosBehavior {
            case .success:
                break
            case .loading:
                try await Task.sleep(for: .seconds(3_600))
            case .failure:
                throw PreviewRepositoryError.loadFailed
        }

        return Array(photos.prefix(perPage))
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        switch statisticsBehavior {
            case .success:
                break
            case .loading:
                try await Task.sleep(for: .seconds(3_600))
            case .failure:
                throw PreviewRepositoryError.loadFailed
        }

        return statistics
    }

    private enum PreviewRepositoryError: LocalizedError {
        case loadFailed

        var errorDescription: String? {
            "The preview detail service is unavailable."
        }
    }
}

#endif
