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
    let context: ResourceLoadFailurePresentation.Context
    let onRetry: () async -> Void

    init(
        failure: ResourceLoadFailure,
        isRetrying: Bool = false,
        context: ResourceLoadFailurePresentation.Context = .pagination,
        onRetry: @escaping () async -> Void
    ) {
        self.failure = failure
        self.isRetrying = isRetrying
        self.context = context
        self.onRetry = onRetry
    }

    var body: some View {
        let presentation = ResourceLoadFailurePresentation(failure, context: context)

        VStack(alignment: .center, spacing: 12) {
            Image(systemName: presentation.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .center, spacing: 4) {
                    Text(presentation.title)
                        .font(.subheadline.weight(.semibold))

                    Text(presentation.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
