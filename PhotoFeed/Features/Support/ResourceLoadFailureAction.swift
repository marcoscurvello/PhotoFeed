//
//  ResourceLoadFailureAction.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import Foundation
import SwiftUI

struct ResourceLoadFailureAction: View {

    let failure: ResourceLoadFailure
    let isRetrying: Bool
    let onRetry: () async -> Void
    let prominent: Bool

    @State private var reachedRetryDeadline: Date?

    init(
        failure: ResourceLoadFailure,
        isRetrying: Bool = false,
        prominent: Bool = false,
        onRetry: @escaping () async -> Void
    ) {
        self.failure = failure
        self.isRetrying = isRetrying
        self.prominent = prominent
        self.onRetry = onRetry
    }

    var body: some View {
        Group {
            switch failure.retryEligibility {
                case .immediate:
                    retryButton

                case .after(let retryAfter):
                    if isRetrying || reachedRetryDeadline == retryAfter || retryAfter <= .now {
                        retryButton
                    } else {
                        delayedRetryMessage(retryAfter: retryAfter)
                    }

                case .unavailable:
                    EmptyView()
            }
        }
        .task(id: failure) {
            reachedRetryDeadline = nil
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        if prominent {
            Button {
                Task { await onRetry() }
            } label: {
                retryButtonLabel
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRetrying)
            .accessibilityLabel(isRetrying ? Text("Retrying") : Text("Retry"))
        } else {
            Button {
                Task { await onRetry() }
            } label: {
                retryButtonLabel
            }
            .buttonStyle(.bordered)
            .disabled(isRetrying)
            .accessibilityLabel(isRetrying ? Text("Retrying") : Text("Retry"))
        }
    }

    private var retryButtonLabel: some View {
        Text("Retry")
            .opacity(isRetrying ? 0 : 1)
            .overlay {
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
    }

    private func delayedRetryMessage(retryAfter: Date) -> some View {
        Text("Retry available in \(Text(timerInterval: .now...retryAfter, countsDown: true, showsHours: false))")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .task(id: retryAfter) {
                let delay = max(retryAfter.timeIntervalSinceNow, 0)

                guard delay > 0 else {
                    reachedRetryDeadline = retryAfter
                    return
                }

                do {
                    try await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    reachedRetryDeadline = retryAfter
                } catch {
                    return
                }
            }
    }
}

#Preview("Retry") {
    ResourceLoadFailureAction(
        failure: .offline,
        onRetry: {}
    )
    .padding()
}

#Preview("Prominent retry") {
    ResourceLoadFailureAction(
        failure: .offline,
        prominent: true,
        onRetry: {}
    )
    .padding()
}

#Preview("Retrying") {
    ResourceLoadFailureAction(
        failure: .offline,
        isRetrying: true,
        onRetry: {}
    )
    .padding()
}

#Preview("Delayed retry") {
    ResourceLoadFailureAction(
        failure: .rateLimited(
            .init(limit: 50, remaining: 0, retryAfter: .now.addingTimeInterval(300))
        ),
        onRetry: {}
    )
    .padding()
}
