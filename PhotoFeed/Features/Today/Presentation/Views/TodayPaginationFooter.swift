//
//  TodayPaginationFooter.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct TodayPaginationFooter: View {

    let viewModel: TodayViewModel

    var body: some View {
        VStack {
            switch viewModel.state {
                case .ready:
                    Color.clear
                        .frame(height: 1)

                case .loading:
                    ProgressView()
                        .padding(.vertical, 24)

                case .failed(let failure), .retrying(let failure):
                    TodayPaginationFailure(
                        failure: failure,
                        isRetrying: viewModel.state == .retrying(failure),
                        onRetry: { await viewModel.retry() }
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Loading footer") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel(behavior: .loading)

    TodayPaginationFooter(viewModel: viewModel)
        .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}

#Preview("Failed footer") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel(behavior: .failure)

    TodayPaginationFooter(viewModel: viewModel)
        .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
}

#Preview("Rate limited footer") {
    @Previewable
    @State var viewModel = TodayPreviewFixtures.makeViewModel(behavior: .rateLimited)

    TodayPaginationFooter(viewModel: viewModel)
        .task { await viewModel.loadIfNeeded(bottomVisibleItemID: nil) }
        .padding(.horizontal, 20)
}
