//
//  PhotoFeedApp.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

@main
struct PhotoFeedApp: App {

    private let dependencies: AppDependencies
//    private let dependencies = AppDependencies.fixture()

    init() {
        do {
            dependencies = try AppDependencies.live()
        } catch {
            // Gotta handle this
            fatalError("Failed to configure PhotoFeed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                todayViewModel: dependencies.todayViewModel,
                imagePipeline: dependencies.imagePipeline
            )
        }
    }
}
