//
//  TodayPaginationFailure.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct TodayPaginationFailure: View {

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
        let presentation = ResourceLoadFailurePresentation(failure)

        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.subheadline.weight(.semibold))

                    Text(presentation.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            ResourceLoadFailureAction(
                failure: failure,
                isRetrying: isRetrying,
                prominent: true,
                onRetry: onRetry
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
}

#Preview("Rate limited pagination") {
    TodayPaginationFailure(
        failure: .rateLimited(
            .init(limit: 50, remaining: 0, retryAfter: .now.addingTimeInterval(300))
        ),
        onRetry: {}
    )
}
