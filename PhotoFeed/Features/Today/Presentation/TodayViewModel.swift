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

    private enum Constants {
        static let pageSize = 10
    }

    enum State: Equatable {
        case ready
        case loading
        case failed(String)
    }

    private(set) var items: [TodayFeedItem] = []
    private(set) var state: State = .ready
    private var nextPage: Int? = 1

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

    func updateCurrentVisibleItem(_ id: TodayFeedItem.ID?) {
        currentVisibleItemID = id
        insertPendingSponsoredPhotosIfPossible()
    }

    func load() async {
        guard state == .ready, let nextPage else {
            return
        }

        await loadPage(nextPage)
    }

    func retry() async {
        guard case .failed = state, let nextPage else {
            return
        }

        await loadPage(nextPage)
    }

    private func loadPage(_ page: Int) async {
        state = .loading

        async let sponsoredLoad: Void = loadSponsoredPhotos()

        await loadOrganicPhotos(page: page)
        await sponsoredLoad
    }

    private func loadOrganicPhotos(page: Int) async {
        do {
            let photos = try await repository.photos(page: page, perPage: Constants.pageSize)

            guard !Task.isCancelled else {
                state = .ready
                return
            }

            guard !photos.isEmpty else {
                nextPage = nil
                state = .ready
                return
            }

            appendOrganicPhotos(photos)

            nextPage = photos.count < Constants.pageSize
            ? nil
            : page + 1

            state = .ready
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadSponsoredPhotos() async {
        do {
            let photos = try await repository.sponsoredPhotos(count: sponsoredRequestCount)

            guard !Task.isCancelled else {
                return
            }

            enqueueSponsoredPhotos(photos)
        } catch {
            // Sponsored loads are best effort and should not block organic feed load
        }
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

    private func appendOrganicPhotos(_ photos: [Photo]) {
        var knownIDs = Set(items.map(\.photo.id))
        let newItems = photos.compactMap { photo -> TodayFeedItem? in
            guard knownIDs.insert(photo.id).inserted else {
                return nil
            }

            return .organic(photo)
        }

        items.append(contentsOf: newItems)
    }

    private func insertPendingSponsoredPhotosIfPossible() {
        guard let visibleIndex = currentVisibleIndex else {
            return
        }

        while let photo = pendingSponsoredPhotos.first {
            guard let insertionIndex = insertionPolicy.insertionIndex(in: items, currentVisibleIndex: visibleIndex) else {
                return
            }

            items.insert(.sponsored(photo), at: insertionIndex)
            pendingSponsoredPhotos.removeFirst()
        }
    }

    private var currentVisibleIndex: Int? {
        guard let currentVisibleItemID else {
            return nil
        }

        return items.firstIndex { $0.id == currentVisibleItemID }
    }
}
