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
    static func makeViewModel() -> DetailViewModel {
        DetailViewModel(
            photo: TodayPreviewFixtures.photo,
            repository: PreviewPhotoDetailRepository(
                photos: TodayPreviewFixtures.photos,
                statistics: PhotoStatistics(
                    views: .init(total: 482_901, change: 14_201, periodDays: 30),
                    likes: .init(total: 8_274, change: 291, periodDays: 30),
                    downloads: .init(total: 12_482, change: 384, periodDays: 30)
                )
            )
        )
    }
}

private nonisolated struct PreviewPhotoDetailRepository: PhotoDetailRepository {
    let photos: [Photo]
    let statistics: PhotoStatistics

    func userPhotos(username: String, page: Int, perPage: Int) async throws -> [Photo] {
        Array(photos.prefix(perPage))
    }

    func statistics(photoID: Photo.ID) async throws -> PhotoStatistics {
        statistics
    }
}

#endif
