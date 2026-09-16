//
//  DetailScrollView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailScrollView: View {

    let photo: Photo
    let viewModel: DetailViewModel
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        let scrollView = ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHero(photo: photo, imagePipeline: imagePipeline)
                DetailContent(
                    user: photo.user,
                    mainPhotoID: photo.id,
                    viewModel: viewModel,
                    imagePipeline: imagePipeline
                )
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollIndicators(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)

        if #available(iOS 26.0, *) {
            scrollView
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            scrollView
        }
    }
}

#Preview {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel()

    NavigationStack {
        DetailScrollView(
            photo: viewModel.photo,
            viewModel: viewModel,
            imagePipeline: TodayPreviewFixtures.imagePipeline
        )
    }
    .task { await viewModel.load() }
}
