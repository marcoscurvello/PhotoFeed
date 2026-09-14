//
//  TodayView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct TodayView: View {

    @Environment(\.scenePhase) private var scenePhase

    let viewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline
    let onSelect: (Photo) -> Void

    @State private var bottomVisibleItemID: TodayFeedItem.ID?
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                header
                content
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
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var photoFeed: some View {
        ForEach(viewModel.items) { item in
            TodayPhotoRow(
                item: item,
                style: viewModel.photoStyle(for: item),
                imagePipeline: imagePipeline
            ) {
                onSelect(item.photo)
            }
            .anchorPreference(
                key: TodayFeedItemBoundsPreferenceKey.self,
                value: .bounds
            ) { [item.id: $0] }
        }

        paginationFooter
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty {
            switch viewModel.state {
                case .ready:
                    photoFeed

                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 80)

                case .failed(let message):
                    errorView(message: message)
            }
        } else {
            photoFeed
        }
    }

    private var paginationFooter: some View {
        VStack {
            switch viewModel.state {
                case .loading:
                    ProgressView()
                        .padding(.vertical, 24)

                case .failed:
                    Button("Retry") {
                        Task {
                            await viewModel.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 24)

                case .ready:
                    Color.clear
                        .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func updateSponsoredLoadingActivity() {
        let isActive = hasAppeared && scenePhase == .active
        viewModel.setSponsoredLoadingActive(isActive)

        if isActive {
            viewModel.updateCurrentVisibleItem(bottomVisibleItemID)
        }
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
            .padding(.vertical, 24)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
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
