//
//  TodayFeedActivityModifier.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

private struct TodayFeedActivityModifier: ViewModifier {

    private enum Constants {
        static let imagePrefetchWindowSize = 3
    }

    let viewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAppeared = false
    @State private var bottomVisibleItem: BottomVisibleItem?

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TodayFeedItemBoundsPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    let visibleItem = bottomVisibleItem(anchors: anchors, in: proxy)

                    Color.clear
                        .onChange(of: visibleItem, initial: true) { _, newValue in
                            bottomVisibleItem = newValue
                        }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                hasAppeared = true
                updateSponsoredLoadingActivity()
            }
            .onDisappear {
                hasAppeared = false
                updateSponsoredLoadingActivity()
            }
            .onChange(of: scenePhase) {
                updateSponsoredLoadingActivity()
            }
            .onChange(of: bottomVisibleItem, initial: true) { _, newValue in
                viewModel.updateCurrentVisibleItem(
                    newValue?.id,
                    isImmediateInsertionOffscreenSafe: newValue?.isInsertionOffscreenSafe ?? false
                )
            }
            .task(id: bottomVisibleItem?.id) {
                await viewModel.loadIfNeeded(bottomVisibleItemID: bottomVisibleItem?.id)
            }
            .task(id: PrefetchWindowKey(
                bottomVisibleItemID: bottomVisibleItem?.id,
                itemCount: viewModel.items.count
            )) {
                await prefetchUpcomingImages(after: bottomVisibleItem?.id)
            }
    }

    private func updateSponsoredLoadingActivity() {
        let isActive = hasAppeared && scenePhase == .active
        viewModel.setSponsoredLoadingActive(isActive)

        if isActive {
            viewModel.updateCurrentVisibleItem(
                bottomVisibleItem?.id,
                isImmediateInsertionOffscreenSafe: bottomVisibleItem?.isInsertionOffscreenSafe ?? false
            )
        }
    }

    private func bottomVisibleItem(
        anchors: [TodayFeedItem.ID: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> BottomVisibleItem? {

        let viewport = proxy.frame(in: .local)
        var bottomVisibleItem: (id: TodayFeedItem.ID, frame: CGRect)?

        for (id, anchor) in anchors {
            let frame = proxy[anchor]

            guard frame.intersection(viewport).height > 0 else {
                continue
            }

            if let bottomVisibleItem, bottomVisibleItem.frame.maxY >= frame.maxY {
                continue
            }

            bottomVisibleItem = (id, frame)
        }

        guard let bottomVisibleItem else {
            return nil
        }

        return BottomVisibleItem(
            id: bottomVisibleItem.id,
            isInsertionOffscreenSafe: bottomVisibleItem.frame.maxY >= viewport.maxY
        )
    }

    private func prefetchUpcomingImages(after bottomVisibleItemID: TodayFeedItem.ID?) async {
        let upcomingURLs = viewModel.upcomingRegularImageURLs(
            after: bottomVisibleItemID,
            limit: Constants.imagePrefetchWindowSize
        )

        guard !upcomingURLs.isEmpty else {
            return
        }

        await imagePipeline.prefetch(upcomingURLs)
    }
}

extension View {

    func todayFeedActivity(
        viewModel: TodayViewModel,
        imagePipeline: RemoteImagePipeline
    ) -> some View {

        modifier(
            TodayFeedActivityModifier(
                viewModel: viewModel,
                imagePipeline: imagePipeline
            )
        )
    }
}

private struct BottomVisibleItem: Equatable {
    let id: TodayFeedItem.ID
    let isInsertionOffscreenSafe: Bool
}

private struct PrefetchWindowKey: Equatable {
    let bottomVisibleItemID: TodayFeedItem.ID?
    let itemCount: Int
}
