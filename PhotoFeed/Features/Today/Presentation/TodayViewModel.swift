//
//  TodayViewModel.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {

    private(set) var photos: [Photo] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any PhotosRepository

    init(repository: any PhotosRepository) {
        self.repository = repository
    }

    func load() async {
        guard photos.isEmpty, !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            photos = try await repository.photos(page: 1, perPage: 10)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retry() async {
        errorMessage = nil
        await load()
    }
}
