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

    static let imagePipeline = RemoteImagePipeline()

    static let photo = Photo(
        id: .init(rawValue: "preview-photo"),
        width: 2448,
        height: 3264,
        colorHex: "#6E633A",
        description: "A quiet architectural interior.",
        imageURLs: .init(
            full: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=1600")!,
            regular: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=1080")!,
            small: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=600")!,
            thumbnail: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=200")!
        ),
        user: User(
            id: .init(rawValue: "preview-user"),
            username: "alex",
            name: "Alex Morgan",
            avatarURL: URL(string: "https://images.unsplash.com/profile-1445820467148-5a882b9d7287?w=128")!,
            webpageURL: URL(string: "https://unsplash.com/@alex")!
        ),
        webpageURL: URL(string: "https://unsplash.com")!
    )

    static let photos = [
        photo,
        Photo(
            id: .init(rawValue: "preview-photo-2"),
            width: 5184,
            height: 3456,
            colorHex: "#A6A8AA",
            description: "City architecture in soft light.",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1461988320302-91bde64fc8e4?w=1600")!,
                regular: URL(string: "https://images.unsplash.com/photo-1461988320302-91bde64fc8e4?w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1461988320302-91bde64fc8e4?w=600")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1461988320302-91bde64fc8e4?w=200")!
            ),
            user: User(
                id: .init(rawValue: "preview-user-2"),
                username: "jamie",
                name: "Jamie Lee",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1445820467148-5a882b9d7287?w=128")!,
                webpageURL: URL(string: "https://unsplash.com/@jamie")!
            ),
            webpageURL: URL(string: "https://unsplash.com")!
        )
    ]

    nonisolated struct PreviewPhotosRepository: PhotosRepository {
        let photos: [Photo]
        let sponsoredPhotos: [Photo]

        func photos(page: Int, perPage: Int) async throws -> PhotoPage {
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
    }

    @MainActor
    static func makeViewModel() -> TodayViewModel {
        TodayViewModel(repository: PreviewPhotosRepository(photos: photos, sponsoredPhotos: photos))
    }
}

#endif
