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

#Preview {
    NavigationStack {
        DetailView(
            photo: PhotoPreviewFixtures.detailPhoto,
            viewModel: DetailPreviewFixtures.makeViewModel(),
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
}
