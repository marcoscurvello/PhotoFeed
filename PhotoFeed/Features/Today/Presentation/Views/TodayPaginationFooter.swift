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

                case .failed:
                    Button("Retry") {
                        Task {
                            await viewModel.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 24)
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
