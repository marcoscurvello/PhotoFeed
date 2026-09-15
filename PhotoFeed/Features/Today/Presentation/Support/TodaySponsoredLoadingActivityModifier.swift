//
//  TodaySponsoredLoadingActivityModifier.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

private struct TodaySponsoredLoadingActivityModifier: ViewModifier {

    let viewModel: TodayViewModel
    let bottomVisibleItemID: TodayFeedItem.ID?

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                hasAppeared = true
                updateSponsoredLoadingActivity()
            }
            .onDisappear {
                hasAppeared = false
                updateSponsoredLoadingActivity()
            }
            .onChange(of: scenePhase) {
                updateSponsoredLoadingActivity()
            }
    }

    private func updateSponsoredLoadingActivity() {
        let isActive = hasAppeared && scenePhase == .active
        viewModel.setSponsoredLoadingActive(isActive)

        if isActive {
            viewModel.updateCurrentVisibleItem(bottomVisibleItemID)
        }
    }
}

extension View {

    func todaySponsoredLoadingActivity(
        viewModel: TodayViewModel,
        bottomVisibleItemID: TodayFeedItem.ID?
    ) -> some View {

        modifier(
            TodaySponsoredLoadingActivityModifier(
                viewModel: viewModel,
                bottomVisibleItemID: bottomVisibleItemID
            )
        )
    }
}
