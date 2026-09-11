//
//  ContentView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct ContentView: View {

    let dependencies: AppDependencies

    @Namespace private var detailTransitionNamespace
    @State private var selectedItem: TodayFeedItem?

    var body: some View {
        TodayView(
            viewModel: dependencies.todayViewModel,
            imagePipeline: dependencies.imagePipeline,
            transitionNamespace: detailTransitionNamespace
        ) { item in
            selectedItem = item
        }
        .fullScreenCover(item: $selectedItem) { item in
            DetailView(
                viewModel: dependencies.makeDetailViewModel(for: item.photo),
                imagePipeline: dependencies.imagePipeline
            )
            .navigationTransition(
                .zoom(
                    sourceID: item.id,
                    in: detailTransitionNamespace
                )
            )
        }
    }
}

#Preview {
    ContentView(dependencies: .fixture())
}
