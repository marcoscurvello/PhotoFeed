//
//  TodayFeedSection.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct TodayFeedSection: View {

    let viewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline
    let transitionNamespace: Namespace.ID
    let onSelect: (Photo) -> Void

    var body: some View {
        if viewModel.items.isEmpty {
            switch viewModel.state {
                case .ready:
                    EmptyView()

                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 80)

                case .failed(let message):
                    TodayErrorView(message: message) {
                        await viewModel.retry()
                    }
            }
        } else {
            TodayContent(
                viewModel: viewModel,
                imagePipeline: imagePipeline,
                transitionNamespace: transitionNamespace,
                onSelect: onSelect
            )
        }
    }
}

#Preview("Loaded feed") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel()
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        LazyVStack(spacing: 24) {
            TodayFeedSection(
                viewModel: viewModel,
                imagePipeline: TodayPreviewFixtures.imagePipeline,
                transitionNamespace: transitionNamespace,
                onSelect: { _ in }
            )
        }
        .padding(.vertical)
    }
    .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}

#Preview("Loading feed") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel(behavior: .loading)
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        LazyVStack(spacing: 24) {
            TodayFeedSection(
                viewModel: viewModel,
                imagePipeline: TodayPreviewFixtures.imagePipeline,
                transitionNamespace: transitionNamespace,
                onSelect: { _ in }
            )
        }
        .padding(.vertical)
    }
    .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}

#Preview("Failed feed") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel(behavior: .failure)
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        LazyVStack(spacing: 24) {
            TodayFeedSection(
                viewModel: viewModel,
                imagePipeline: TodayPreviewFixtures.imagePipeline,
                transitionNamespace: transitionNamespace,
                onSelect: { _ in }
            )
        }
        .padding(.vertical)
    }
    .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}
