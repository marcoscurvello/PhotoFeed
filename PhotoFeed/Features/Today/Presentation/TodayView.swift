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

    @State private var bottomVisibleItemID: TodayFeedItem.ID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                TodayHeader()
                TodayFeedSection(
                    viewModel: viewModel,
                    imagePipeline: imagePipeline,
                    onSelect: onSelect
                )

            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .overlayPreferenceValue(TodayFeedItemBoundsPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                let visibleItemID = bottomVisibleItemID(anchors: anchors, in: proxy)

                Color.clear
                    .onAppear {
                        updateBottomVisibleItem(visibleItemID)
                    }
                    .onChange(of: visibleItemID) { _, newValue in
                        updateBottomVisibleItem(newValue)
                    }
            }
            .allowsHitTesting(false)
        }
        .task(id: bottomVisibleItemID) {
            viewModel.updateCurrentVisibleItem(bottomVisibleItemID)
            await viewModel.loadIfNeeded(bottomVisibleItemID: bottomVisibleItemID)
        }
        .todaySponsoredLoadingActivity(
            viewModel: viewModel,
            bottomVisibleItemID: bottomVisibleItemID
        )
    }

    private func updateBottomVisibleItem(_ id: TodayFeedItem.ID?) {
        bottomVisibleItemID = id
    }

    private func bottomVisibleItemID(
        anchors: [TodayFeedItem.ID: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> TodayFeedItem.ID? {

        let viewport = proxy.frame(in: .local)
        return anchors
            .map { (id: $0.key, frame: proxy[$0.value]) }
            .filter { $0.frame.intersection(viewport).height > 0 }
            .max { $0.frame.maxY < $1.frame.maxY }?
            .id
    }
}

#Preview {
    TodayView(
        viewModel: TodayPreviewFixtures.makeViewModel(),
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        onSelect: { _ in }
    )
}
