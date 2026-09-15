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
    @State private var selectedPhoto: Photo?

    var body: some View {
        NavigationStack {
            TodayView(
                viewModel: dependencies.todayViewModel,
                imagePipeline: dependencies.imagePipeline,
                transitionNamespace: detailTransitionNamespace
            ) { photo in
                selectedPhoto = photo
            }
            .navigationDestination(item: $selectedPhoto) { photo in
                detailDestination(for: photo)
            }
        }
    }

    @ViewBuilder
    private func detailDestination(for photo: Photo) -> some View {
        let detailView = DetailView(
            viewModel: dependencies.makeDetailViewModel(for: photo),
            imagePipeline: dependencies.imagePipeline
        )

        if #available(iOS 18.0, *) {
            detailView.navigationTransition(
                .zoom(
                    sourceID: photo.id,
                    in: detailTransitionNamespace
                )
            )
        } else {
            detailView
        }
    }
}

#Preview {
    ContentView(dependencies: .fixture())
}
