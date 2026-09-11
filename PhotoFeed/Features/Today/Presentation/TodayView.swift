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

    @State private var visibleItemIDs: Set<TodayFeedItem.ID> = []
    @State private var visibilityRevision = 0
    @State private var hasAppeared = false
    @State private var isSponsoredLoadingActive = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                header
                content
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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
        .task {
            await viewModel.load()
        }
        .task(id: visibilityRevision) {
            await updateBottomVisibleItem()
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

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 80)
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
            .onGeometryChange(for: Bool.self) { proxy in
                let frame = proxy.frame(in: .scrollView)
                guard let bounds = proxy.bounds(of: .scrollView) else {
                    return false
                }

                let viewport = CGRect(origin: .zero, size: bounds.size)
                return frame.intersection(viewport).height > 0
            } action: { isVisible in
                updateVisibility(of: item.id, isVisible: isVisible)
            }
            .onDisappear {
                removeVisibleItem(item.id)
            }
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
                loadingView

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
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }

    private func updateVisibility(of id: TodayFeedItem.ID, isVisible: Bool) {
        let didChange: Bool

        if isVisible {
            didChange = visibleItemIDs.insert(id).inserted
        } else {
            didChange = visibleItemIDs.remove(id) != nil
        }

        guard didChange else {
            return
        }

        visibilityRevision &+= 1
    }

    private func removeVisibleItem(_ id: TodayFeedItem.ID) {
        guard visibleItemIDs.remove(id) != nil else {
            return
        }

        visibilityRevision &+= 1
    }

    private func updateBottomVisibleItem() async {
        await Task.yield()

        guard !Task.isCancelled else {
            return
        }

        guard let bottomVisibleItem = viewModel.items.last(where: { visibleItemIDs.contains($0.id) }) else {
            viewModel.updateCurrentVisibleItem(nil)
            return
        }

        viewModel.updateCurrentVisibleItem(bottomVisibleItem.id)
    }

    private func updateSponsoredLoadingActivity() {
        let isActive = hasAppeared && scenePhase == .active
        guard isSponsoredLoadingActive != isActive else {
            return
        }

        isSponsoredLoadingActive = isActive
        viewModel.setSponsoredLoadingActive(isActive)

        if isActive {
            visibilityRevision &+= 1
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
