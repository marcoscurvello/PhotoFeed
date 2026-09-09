//
//  PhotoFeedApp.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

@main
struct PhotoFeedApp: App {

    private enum Environment {
        case fixture, live
    }

    private static let environment: Environment = .fixture

    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try Self.makeDependencies()
        } catch {
            fatalError("Failed to configure PhotoFeed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }

    private static func makeDependencies() throws -> AppDependencies {
        switch environment {
        case .fixture:
            AppDependencies.fixture()

        case .live:
            try AppDependencies.live()
        }
    }
}
