//
//  DetailStatisticsMetrics.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct DetailStatisticsMetrics: View {

    let views: PhotoStatistics.Metric
    let likes: PhotoStatistics.Metric?
    let downloads: PhotoStatistics.Metric

    var body: some View {
        HStack(spacing: 12) {
            DetailMetric(
                title: "Views",
                systemImage: "eye",
                metric: views
            )

            if let likes {
                DetailMetric(
                    title: "Likes",
                    systemImage: "heart",
                    metric: likes
                )
            }

            DetailMetric(
                title: "Downloads",
                systemImage: "arrow.down",
                metric: downloads
            )
        }
    }
}

#Preview {
    DetailStatisticsMetrics(
        views: .init(total: 482_901, change: 14_201, periodDays: 30),
        likes: .init(total: 8_421, change: 268, periodDays: 30),
        downloads: .init(total: 24_674, change: 971, periodDays: 30)
    )
    .padding()
}
