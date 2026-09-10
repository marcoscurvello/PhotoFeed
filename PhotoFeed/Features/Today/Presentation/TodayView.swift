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

    @State private var visibleItemIDs: Set<TodayFeedItem.ID> = []
    @State private var visibilityRevision = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                header
                content
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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
        let styles = photoStyles

        ForEach(viewModel.items) { item in
            TodayPhotoRow(
                item: item,
                style: styles[item.id] ?? .card,
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

    private var photoStyles: [TodayFeedItem.ID: PhotoCardStyle] {
        var styles: [TodayFeedItem.ID: PhotoCardStyle] = [:]
        var organicIndex = 0

        for item in viewModel.items {
            if item.isSponsored {
                styles[item.id] = .card
                continue
            }

            styles[item.id] = organicIndex.isMultiple(of: 4) ? .fullBleed : .card
            organicIndex += 1
        }

        return styles
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
