//
//  ContentView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct ContentView: View {

    let dependencies: AppDependencies

    @State private var selectedPhoto: Photo?

    var body: some View {
        NavigationStack {
            TodayView(
                viewModel: dependencies.todayViewModel,
                imagePipeline: dependencies.imagePipeline
            ) { photo in
                selectedPhoto = photo
            }
            .navigationDestination(item: $selectedPhoto) { photo in
                DetailView(
                    viewModel: dependencies.makeDetailViewModel(for: photo),
                    imagePipeline: dependencies.imagePipeline
                )
            }
        }
    }
}

#Preview {
    ContentView(dependencies: .fixture())
}
