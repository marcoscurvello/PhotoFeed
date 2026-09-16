//
//  TodayContent.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct TodayContent: View {

    let viewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline
    let transitionNamespace: Namespace.ID
    let onSelect: (Photo) -> Void

    var body: some View {
        ForEach(viewModel.items) { item in
            TodayPhotoRow(
                item: item,
                style: viewModel.photoStyle(for: item),
                imagePipeline: imagePipeline,
                transitionNamespace: transitionNamespace
            ) {
                onSelect(item.photo)
            }
            .anchorPreference(
                key: TodayFeedItemBoundsPreferenceKey.self,
                value: .bounds
            ) { [item.id: $0] }
        }

        TodayPaginationFooter(viewModel: viewModel)
    }
}

#Preview("Loaded content") {
    @Previewable @State var viewModel = TodayPreviewFixtures.makeViewModel()
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        LazyVStack(spacing: 24) {
            TodayContent(
                viewModel: viewModel,
                imagePipeline: PhotoPreviewFixtures.imagePipeline,
                transitionNamespace: transitionNamespace,
                onSelect: { _ in }
            )
        }
        .padding(.vertical)
    }
    .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}
