//
//  TodayErrorView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct TodayErrorView: View {

    let message: String
    let onRetry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Unable to load photos", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

}
#Preview("Loading error") {
    TodayErrorView(
        message: "Check your connection and try loading the latest photos again.",
        onRetry: {}
    )
}
