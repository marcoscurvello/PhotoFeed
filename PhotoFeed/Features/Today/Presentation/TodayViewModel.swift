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

    private(set) var items: [TodayFeedItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any PhotosRepository
    private let insertionPolicy: SponsoredInsertionPolicy
    private let sponsoredRequestCount: Int

    private var pendingSponsoredPhotos: [Photo] = []
    private var currentVisibleItemID: TodayFeedItem.ID?

    init(
        repository: any PhotosRepository,
        insertionPolicy: SponsoredInsertionPolicy = SponsoredInsertionPolicy(),
        sponsoredRequestCount: Int = 3
    ) {
        self.repository = repository
        self.insertionPolicy = insertionPolicy
        self.sponsoredRequestCount = sponsoredRequestCount
    }

    func load() async {
        guard items.isEmpty, !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        async let sponsoredPhotos = repository.sponsoredPhotos(count: sponsoredRequestCount)

        do {
            let photos = try await repository.photos(page: 1, perPage: 10)

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            items = photos.map { .organic($0) }
            isLoading = false
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return
        }

        do {
            let photos = try await sponsoredPhotos

            guard !Task.isCancelled else {
                return
            }

            enqueueSponsoredPhotos(photos)
        } catch {
            // Failure must not prevent the organic feed from being displayed
        }
    }

    func updateCurrentVisibleItem(_ id: TodayFeedItem.ID?) {
        currentVisibleItemID = id
        insertPendingSponsoredPhotosIfPossible()
    }

    func retry() async {
        guard items.isEmpty else {
            return
        }

        await load()
    }

    private func enqueueSponsoredPhotos(_ photos: [Photo]) {
        let displayedIDs = Set(items.map(\.photo.id))
        var knownIDs = displayedIDs.union(pendingSponsoredPhotos.map(\.id))

        for photo in photos where !knownIDs.contains(photo.id) {
            pendingSponsoredPhotos.append(photo)
            knownIDs.insert(photo.id)
        }

        insertPendingSponsoredPhotosIfPossible()
    }

    private func insertPendingSponsoredPhotosIfPossible() {
        while let photo = pendingSponsoredPhotos.first {
            let visibleIndex = currentVisibleIndex

            guard let insertionIndex = insertionPolicy.insertionIndex(in: items, currentVisibleIndex: visibleIndex) else {
                return
            }

            items.insert(.sponsored(photo), at: insertionIndex)
            pendingSponsoredPhotos.removeFirst()
        }
    }

    private var currentVisibleIndex: Int {
        guard let currentVisibleItemID,
              let index = items.firstIndex(where: { $0.id == currentVisibleItemID }) else {
            return 0
        }

        return index
    }
}
