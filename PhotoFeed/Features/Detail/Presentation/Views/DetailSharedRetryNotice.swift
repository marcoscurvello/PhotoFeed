//
//  DetailSharedRetryNotice.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 18/09/2026.
//

import SwiftUI

struct DetailSharedRetryNotice: View {

    let viewModel: DetailViewModel

    var body: some View {
        if let failure = viewModel.sharedRetryFailure {
            let presentation = ResourceLoadFailurePresentation(failure, context: .detail)

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: presentation.systemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
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
                    isRetrying: viewModel.isRetryingSharedResources,
                    onRetry: { await viewModel.retrySharedResources() }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = {
        let retryAfter = Date.now.addingTimeInterval(300)
        let failure = ResourceLoadFailure.rateLimited(
            .init(limit: 50, remaining: 0, retryAfter: retryAfter)
        )

        return DetailPreviewFixtures.makeViewModel(
            userPhotosBehavior: .resourceFailure(failure),
            statisticsBehavior: .resourceFailure(failure)
        )
    }()

    ZStack {
        Color.clear
        DetailSharedRetryNotice(viewModel: viewModel)
    }
    .task { await viewModel.load() }
}
