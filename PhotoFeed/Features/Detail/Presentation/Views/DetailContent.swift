//
//  DetailContent.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailContent: View {

    let user: User
    let viewModel: DetailViewModel
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        let usesSharedRetryNotice = viewModel.sharedRetryFailure != nil

        VStack(alignment: .leading, spacing: 32) {
            DetailPhotographer(user: user, imagePipeline: imagePipeline)
            DetailStatisticsSection(
                viewModel: viewModel,
                usesSharedRetryNotice: usesSharedRetryNotice
            )
            DetailUserPhotosSection(
                viewModel: viewModel,
                imagePipeline: imagePipeline,
                photographerName: user.name,
                usesSharedRetryNotice: usesSharedRetryNotice
            )
            DetailSharedRetryNotice(viewModel: viewModel)
        }
        .padding(.top, 20)
        .padding(.bottom, 32)
        .background(.background)
    }
}

#Preview {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel()

    ScrollView {
        DetailContent(
            user: PhotoPreviewFixtures.detailPhoto.user,
            viewModel: viewModel,
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
    .task { await viewModel.load() }
}
