//
//  DetailView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct DetailView: View {

    @State private var viewModel: DetailViewModel

    let imagePipeline: RemoteImagePipeline

    init(viewModel: DetailViewModel, imagePipeline: RemoteImagePipeline) {
        _viewModel = State(initialValue: viewModel)
        self.imagePipeline = imagePipeline
    }

    var body: some View {
        DetailScrollView(
            photo: viewModel.photo,
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
            viewModel: DetailPreviewFixtures.makeViewModel(),
            imagePipeline: TodayPreviewFixtures.imagePipeline
        )
    }
}
