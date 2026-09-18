//
//  TodayErrorView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct TodayErrorView: View {

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

        ContentUnavailableView {
            Label(presentation.title, systemImage: presentation.systemImage)
                .symbolEffect(.appear)
        } description: {
            Text(presentation.message)
        } actions: {
            ResourceLoadFailureAction(
                failure: failure,
                isRetrying: isRetrying,
                prominent: true,
                onRetry: onRetry
            )
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical)
        .padding(.horizontal, 20)
    }

}
#Preview("Feed error") {
    TodayErrorView(
        failure: .offline,
        onRetry: {}
    )
}

#Preview("Retrying feed error") {
    TodayErrorView(
        failure: .offline,
        isRetrying: true,
        onRetry: {}
    )
}
