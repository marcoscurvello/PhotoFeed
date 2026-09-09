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
            .navigationDestination(isPresented: isShowingDetail) {
                if let selectedPhoto {
                    DetailView(
                        viewModel: dependencies.makeDetailViewModel(for: selectedPhoto),
                        imagePipeline: dependencies.imagePipeline
                    )
                }
            }
        }
    }

    private var isShowingDetail: Binding<Bool> {
        Binding(
            get: {
                selectedPhoto != nil
            },
            set: { isPresented in
                if !isPresented {
                    selectedPhoto = nil
                }
            }
        )
    }
}

#Preview {
    ContentView(dependencies: .fixture())
}
