//
//  ContentView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct ContentView: View {

    let todayViewModel: TodayViewModel
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        NavigationStack {
            TodayView(viewModel: todayViewModel, imagePipeline: imagePipeline) { _ in
                // Detail navigation
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.fixture()

    ContentView(
        todayViewModel: dependencies.todayViewModel,
        imagePipeline: dependencies.imagePipeline
    )
}
