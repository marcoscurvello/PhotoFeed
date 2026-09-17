//
//  DetailStatisticsSection.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailStatisticsSection: View {

    let viewModel: DetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2.bold())

            switch viewModel.statisticsState {
                case .loaded(let statistics):
                    DetailStatisticsMetrics(
                        views: statistics.views,
                        likes: statistics.likes,
                        downloads: statistics.downloads
                    )

                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

                case .failed(let failure), .retrying(let failure):
                    DetailStatisticsFailure(
                        failure: failure,
                        isRetrying: viewModel.statisticsState == .retrying(failure),
                        onRetry: { await viewModel.retryStatistics() }
                    )

                case .idle:
                    EmptyView()
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview("Loaded statistics") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel()

    DetailStatisticsSection(viewModel: viewModel)
        .task { await viewModel.load() }
}

#Preview("Statistics loading") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(
        statisticsBehavior: .loading
    )

    DetailStatisticsSection(viewModel: viewModel)
        .task { await viewModel.load() }
}

#Preview("Statistics failure") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(
        statisticsBehavior: .failure
    )

    DetailStatisticsSection(viewModel: viewModel)
        .task { await viewModel.load() }
}
