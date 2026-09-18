//
//  DetailStatisticsMetric.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailStatisticsMetric: View {

    let title: LocalizedStringResource
    let systemImage: String
    let metric: PhotoStatistics.Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(metric.total, format: .number)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                "\(metric.change, format: .number.sign(strategy: .always(includingZero: false))) / \(metric.periodDays, format: .number) days",
                comment: "Statistics change summary. The first placeholder is the signed change and the second is the number of days in its comparison period."
            )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

}

#Preview {
    DetailStatisticsMetric(
        title: "Views",
        systemImage: "eye",
        metric: .init(total: 482_901, change: 14_201, periodDays: 30)
    )
    .padding()
}
