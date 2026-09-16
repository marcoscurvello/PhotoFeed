//
//  TodayPreviewFixtures.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

#if DEBUG
import Foundation

@MainActor
enum TodayPreviewFixtures {

    enum RepositoryBehavior: Sendable {
        case success
        case loading
        case failure
    }

    static func makeViewModel(behavior: RepositoryBehavior = .success) -> TodayViewModel {
        TodayViewModel(
            repository: PreviewRepository(
                photos: PhotoPreviewFixtures.photos,
                sponsoredPhotos: PhotoPreviewFixtures.sponsoredPhotos,
                behavior: behavior
            )
        )
    }

    private nonisolated struct PreviewRepository: PhotosRepository {
        let photos: [Photo]
        let sponsoredPhotos: [Photo]
        let behavior: RepositoryBehavior

        func photos(page: Int, perPage: Int) async throws -> PhotoPage {
            switch behavior {
                case .success:
                    break
                case .loading:
                    try await Task.sleep(for: .seconds(3_600))
                case .failure:
                    throw PreviewRepositoryError.loadFailed
            }

            let startIndex = (page - 1) * perPage
            let pagePhotos: [Photo]

            if startIndex < photos.count {
                let endIndex = min(startIndex + perPage, photos.count)
                pagePhotos = Array(photos[startIndex..<endIndex])
            } else {
                pagePhotos = []
            }

            return PhotoPage(
                photos: pagePhotos,
                page: page,
                perPage: perPage,
                total: photos.count
            )
        }

        func sponsoredPhotos(count: Int) async throws -> [Photo] {
            Array(sponsoredPhotos.prefix(count))
        }

        private enum PreviewRepositoryError: LocalizedError {
            case loadFailed

            var errorDescription: String? {
                "The preview photo service is unavailable."
            }
        }
    }
}
#endif
