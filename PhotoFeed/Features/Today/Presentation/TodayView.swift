//
//  TodayView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct TodayView: View {

    let viewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline
    let transitionNamespace: Namespace.ID
    let onSelect: (Photo) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                TodayHeader()
                TodayFeedSection(
                    viewModel: viewModel,
                    imagePipeline: imagePipeline,
                    transitionNamespace: transitionNamespace,
                    onSelect: onSelect
                )
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .todayFeedActivity(
            viewModel: viewModel,
            imagePipeline: imagePipeline
        )
    }
}

#Preview {
    @Previewable @Namespace var transitionNamespace

    TodayView(
        viewModel: TodayPreviewFixtures.makeViewModel(),
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        transitionNamespace: transitionNamespace,
        onSelect: { _ in }
    )
}
