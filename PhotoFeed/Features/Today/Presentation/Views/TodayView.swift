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
    let onSelect: (Photo) -> Void

    @State private var currentVisibleItemID: TodayFeedItem.ID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                header

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    errorView(message: errorMessage)
                } else {
                    photoFeed
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollPosition(id: $currentVisibleItemID, anchor: .top)
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load()
        }
        .onChange(of: currentVisibleItemID) { _, id in
            viewModel.updateCurrentVisibleItem(id)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Discover")
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var photoFeed: some View {
        ForEach(viewModel.items) { item in
            PhotoCardView(
                photo: item.photo,
                imagePipeline: imagePipeline,
                isSponsored: item.isSponsored
            ) {
                onSelect(item.photo)
            }
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to load photos", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
        }
        .padding(.top, 60)
    }
}

#Preview {
    TodayView(
        viewModel: TodayPreviewFixtures.makeViewModel(),
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        onSelect: { _ in }
    )
}
