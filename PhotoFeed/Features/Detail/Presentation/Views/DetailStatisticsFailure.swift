//
//  DetailStatisticsFailure.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct DetailStatisticsFailure: View {

    let failure: ResourceLoadFailure
    let isRetrying: Bool
    let onRetry: () async -> Void

    init(
        failure: ResourceLoadFailure,
        isRetrying: Bool = false,
        onRetry: @escaping () async -> Void
    ) {
        self.failure = failure
        self.isRetrying = isRetrying
        self.onRetry = onRetry
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Statistics unavailable")
                    .font(.subheadline.weight(.semibold))

                Text(ResourceLoadFailurePresentation(failure, context: .statistics).message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            ResourceLoadFailureAction(
                failure: failure,
                isRetrying: isRetrying,
                onRetry: onRetry
            )
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview("Statistics service unavailable") {
    DetailStatisticsFailure(
        failure: .serviceUnavailable(retryAfter: .now.addingTimeInterval(300)),
        onRetry: {}
    )
    .padding()
}
