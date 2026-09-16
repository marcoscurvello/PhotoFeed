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

            if let statistics = viewModel.statistics {
                HStack(spacing: 12) {
                    DetailMetric(
                        title: "Views",
                        systemImage: "eye",
                        metric: statistics.views
                    )

                    if let likes = statistics.likes {
                        DetailMetric(
                            title: "Likes",
                            systemImage: "heart",
                            metric: likes
                        )
                    }

                    DetailMetric(
                        title: "Downloads",
                        systemImage: "arrow.down",
                        metric: statistics.downloads
                    )
                }
            } else if viewModel.isLoadingStatistics {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if viewModel.statisticsErrorMessage != nil {
                DetailStatisticsFailure(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct DetailStatisticsFailure: View {

    let viewModel: DetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Statistics unavailable")
                    .font(.subheadline.weight(.semibold))

                Text("We couldn't load statistics for this photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await viewModel.retryStatistics()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
