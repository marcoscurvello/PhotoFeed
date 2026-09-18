//
//  DetailView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct DetailView: View {

    @State private var viewModel: DetailViewModel

    let photo: Photo
    let imagePipeline: RemoteImagePipeline

    init(photo: Photo, viewModel: DetailViewModel, imagePipeline: RemoteImagePipeline) {
        _viewModel = State(initialValue: viewModel)
        self.photo = photo
        self.imagePipeline = imagePipeline
    }

    var body: some View {
        DetailScrollView(
            photo: photo,
            viewModel: viewModel,
            imagePipeline: imagePipeline
        )
        .task {
            await viewModel.load()
        }
    }
}
#Preview("Loading detail") {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(
                userPhotosBehavior: .loading,
                statisticsBehavior: .loading
            ),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}

#Preview("Loaded detail") {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}

#Preview("Detail failure") {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(
                userPhotosBehavior: .failure,
                statisticsBehavior: .failure
            ),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}

#Preview("Statistics rate limited") {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(
                statisticsBehavior: .resourceFailure(
                    .rateLimited(
                        .init(
                            limit: 50,
                            remaining: 0,
                            retryAfter: .now.addingTimeInterval(300)
                        )
                    )
                )
            ),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}

#Preview("More photos rate limited") {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(
                userPhotosBehavior: .resourceFailure(
                    .rateLimited(
                        .init(
                            limit: 50,
                            remaining: 0,
                            retryAfter: .now.addingTimeInterval(300)
                        )
                    )
                )
            ),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}

#Preview("Detail deferred retry") {
    let retryAfter = Date.now.addingTimeInterval(300)

    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(
                userPhotosBehavior: .resourceFailure(
                    .rateLimited(.init(limit: 50, remaining: 0, retryAfter: retryAfter))
                ),
                statisticsBehavior: .resourceFailure(
                    .rateLimited(.init(limit: 50, remaining: 0, retryAfter: retryAfter))
                )
            ),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}
