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

#Preview("Loaded feed") {
    @Previewable @State var viewModel = TodayPreviewFixtures.makeViewModel()
    @Previewable @Namespace var transitionNamespace

    TodayView(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        transitionNamespace: transitionNamespace,
        onSelect: { _ in }
    )
}

#Preview("Loading feed") {
    @Previewable @State var viewModel = TodayPreviewFixtures.makeViewModel(
        behavior: .loading
    )
    @Previewable @Namespace var transitionNamespace

    TodayView(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        transitionNamespace: transitionNamespace,
        onSelect: { _ in }
    )
}

#Preview("Feed failure") {
    @Previewable @State var viewModel = TodayPreviewFixtures.makeViewModel(
        behavior: .failure
    )
    @Previewable @Namespace var transitionNamespace

    TodayView(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        transitionNamespace: transitionNamespace,
        onSelect: { _ in }
    )
}

#Preview("Rate limited feed") {
    @Previewable @State var viewModel = TodayPreviewFixtures.makeViewModel(
        behavior: .rateLimited
    )
    @Previewable @Namespace var transitionNamespace

    TodayView(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        transitionNamespace: transitionNamespace,
        onSelect: { _ in }
    )
}
