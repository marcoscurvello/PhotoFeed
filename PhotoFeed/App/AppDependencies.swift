//
//  AppDependencies.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

@MainActor
struct AppDependencies {

    let todayViewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline

    private let repository: any PhotosRepository & PhotoDetailRepository

    init(repository: any PhotosRepository & PhotoDetailRepository) {
        self.repository = repository
        todayViewModel = TodayViewModel(repository: repository)
        imagePipeline = RemoteImagePipeline()
    }

    func makeDetailViewModel(for photo: Photo) -> DetailViewModel {
        DetailViewModel(photo: photo, repository: repository)
    }

    static func fixture() -> AppDependencies {
        AppDependencies(repository: FixturePhotosRepository())
    }

    static func live(bundle: Bundle = .main) throws -> AppDependencies {
        let configuration = try AppConfiguration(bundle: bundle)
        let client = HTTPClient(baseURL: URL(string: "https://api.unsplash.com")!)
        let api = UnsplashAPI(client: client, accessKey: configuration.unsplashAccessKey)
        let repository = UnsplashPhotosRepository(api: api)

        return AppDependencies(repository: repository)
    }
}
