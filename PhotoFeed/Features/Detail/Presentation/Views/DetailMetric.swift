//
//  DetailMetric.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailMetric: View {

    let title: LocalizedStringResource
    let systemImage: String
    let metric: PhotoStatistics.Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(metric.total.formatted())
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(signed(metric.change)) / \(metric.periodDays)d")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value.formatted())" : value.formatted()
    }
}

#Preview {
    DetailMetric(
        title: "Views",
        systemImage: "eye",
        metric: .init(total: 482_901, change: 14_201, periodDays: 30)
    )
    .padding()
}
