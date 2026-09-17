//
//  TodayViewModel.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import DequeModule
import Foundation
import Observation
import OrderedCollections

@MainActor
@Observable
final class TodayViewModel {

    private enum Constants {
        static let defaultPageSize = 10
    }

    enum State: Equatable {
        case ready
        case loading
        case failed(ResourceLoadFailure)
        case retrying(ResourceLoadFailure)
    }

    private let repository: any PhotosRepository
    private let sponsoredCoordinator: SponsoredCoordinator
    private let sponsoredInsertionPolicy: SponsoredInsertionPolicy
    private let sponsoredConfiguration: SponsoredCoordinatorConfiguration

    private(set) var state: State = .ready

    private var feedItems: OrderedDictionary<TodayFeedItem.ID, TodayFeedItem> = [:]

    var items: OrderedDictionary<TodayFeedItem.ID, TodayFeedItem>.Values {
        feedItems.values
    }

    @ObservationIgnored
    private var admittedPhotoIDs: Set<Photo.ID> = []

    @ObservationIgnored
    private var photoStyles: [Photo.ID: PhotoCardStyle] = [:]

    @ObservationIgnored
    private var pendingSponsoredPhotos: Deque<Photo> = []

    @ObservationIgnored
    private var currentVisibleItemID: TodayFeedItem.ID?

    @ObservationIgnored
    private var isImmediateInsertionOffscreenSafe = false

    @ObservationIgnored
    private var furthestReachedItemID: TodayFeedItem.ID?

    @ObservationIgnored
    private var isSponsoredLoadingActive = false

    @ObservationIgnored
    private var nextPage: Int? = 1

    @ObservationIgnored
    private var sponsoredTask: Task<Void, Never>?

    init(
        repository: any PhotosRepository,
        insertionPolicy: SponsoredInsertionPolicy = SponsoredInsertionPolicy(),
        sponsoredConfiguration: SponsoredCoordinatorConfiguration = SponsoredCoordinatorConfiguration()
    ) {
        self.repository = repository
        self.sponsoredInsertionPolicy = insertionPolicy
        self.sponsoredConfiguration = sponsoredConfiguration

        self.sponsoredCoordinator = SponsoredCoordinator(
            repository: repository,
            configuration: sponsoredConfiguration
        )
    }

    func setSponsoredLoadingActive(_ isActive: Bool) {
        guard isSponsoredLoadingActive != isActive else {
            return
        }

        isSponsoredLoadingActive = isActive

        if isActive {
            replenishSponsoredPhotosIfNeeded()
        } else {
            currentVisibleItemID = nil
            isImmediateInsertionOffscreenSafe = false
            sponsoredTask?.cancel()
        }
    }

    func updateCurrentVisibleItem(_ id: TodayFeedItem.ID?, isImmediateInsertionOffscreenSafe: Bool) {
        guard isSponsoredLoadingActive else {
            currentVisibleItemID = nil
            self.isImmediateInsertionOffscreenSafe = false
            return
        }

        guard
            currentVisibleItemID != id || self.isImmediateInsertionOffscreenSafe != isImmediateInsertionOffscreenSafe
        else {
            return
        }

        currentVisibleItemID = id
        self.isImmediateInsertionOffscreenSafe = isImmediateInsertionOffscreenSafe

        guard let id, let visibleIndex = itemIndex(for: id) else {
            return
        }

        if visibleIndex > (furthestReachedIndex ?? -1) {
            furthestReachedItemID = id
        }

        insertPendingSponsoredPhotosIfPossible()
        replenishSponsoredPhotosIfNeeded()
    }

    func loadIfNeeded(bottomVisibleItemID: TodayFeedItem.ID?) async {
        guard state == .ready, let nextPage else {
            return
        }

        if feedItems.isEmpty {
            guard nextPage == 1, bottomVisibleItemID == nil else {
                return
            }
        } else {
            guard bottomVisibleItemID == feedItems.keys.last else {
                return
            }
        }

        await load(page: nextPage)
    }

    func retry() async {
        guard case .failed(let failure) = state, failure.canRetry(), let nextPage else {
            return
        }

        state = .retrying(failure)
        await load(page: nextPage, retrying: failure)
    }

    func photoStyle(for item: TodayFeedItem) -> PhotoCardStyle {
        guard case .organic(let photo) = item else {
            return .card
        }

        return photoStyles[photo.id] ?? .card
    }

    func upcomingRegularImageURLs(after itemID: TodayFeedItem.ID?, limit: Int) -> [URL] {
        guard let itemID, limit > 0,
              let itemIndex = itemIndex(for: itemID)
        else {
            return []
        }

        return feedItems.values
            .dropFirst(itemIndex + 1)
            .prefix(limit)
            .map(\.photo.imageURLs.regular)
    }

    private var furthestReachedIndex: Int? {
        guard let furthestReachedItemID else {
            return nil
        }

        return itemIndex(for: furthestReachedItemID)
    }

    private func load(page: Int, retrying failure: ResourceLoadFailure? = nil) async {
        if failure == nil {
            state = .loading
        }

        do {
            let photoPage = try await repository.photos(page: page, perPage: Constants.defaultPageSize)

            guard !Task.isCancelled else {
                state = failure.map(State.failed) ?? .ready
                return
            }

            appendOrganicPhotos(photoPage.photos)
            nextPage = photoPage.nextPage

            state = .ready

            insertPendingSponsoredPhotosIfPossible()
            replenishSponsoredPhotosIfNeeded()
        } catch {
            handle(error, retrying: failure)
        }
    }

    private func handle(_ error: Error, retrying failure: ResourceLoadFailure?) {
        guard !isCancellation(error) else {
            state = failure.map(State.failed) ?? .ready
            return
        }

        state = .failed((error as? ResourceLoadFailure) ?? .unknown)
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func appendOrganicPhotos(_ photos: [Photo]) {
        var draftItems = feedItems
        var draftPhotoStyles = photoStyles
        var draftAdmittedPhotoIDs = admittedPhotoIDs
        var admittedIDs = Set<Photo.ID>()

        for photo in photos {
            guard draftAdmittedPhotoIDs.insert(photo.id).inserted else {
                continue
            }

            admittedIDs.insert(photo.id)
            let organicOrdinal = draftPhotoStyles.count

            draftPhotoStyles[photo.id] = organicOrdinal.isMultiple(of: 4)
            ? .fullBleed
            : .card

            let item = TodayFeedItem.organic(photo)
            draftItems[item.id] = item
        }

        guard !admittedIDs.isEmpty else {
            return
        }

        pendingSponsoredPhotos.removeAll { admittedIDs.contains($0.id) }
        admittedPhotoIDs = draftAdmittedPhotoIDs
        photoStyles = draftPhotoStyles
        feedItems = draftItems
    }

    private func replenishSponsoredPhotosIfNeeded() {
        guard
            isSponsoredLoadingActive,
            sponsoredTask == nil,
            pendingSponsoredPhotos.count <= sponsoredConfiguration.lowWatermark
        else {
            return
        }

        let desiredCount = max(sponsoredConfiguration.targetCoverage - pendingSponsoredPhotos.count, 0)
        guard desiredCount > 0 else {
            return
        }

        let excludedIDs = admittedPhotoIDs.union(pendingSponsoredPhotos.map(\.id))

        sponsoredTask = Task { [weak self] in
            guard let self else {
                return
            }

            let photos = await sponsoredCoordinator.loadCandidates(
                count: desiredCount,
                excluding: excludedIDs
            )

            if Task.isCancelled {
                sponsoredTask = nil

                if isSponsoredLoadingActive {
                    replenishSponsoredPhotosIfNeeded()
                }

                return
            }

            sponsoredTask = nil
            receiveSponsoredPhotos(photos)
        }
    }

    private func receiveSponsoredPhotos(_ photos: [Photo]) {
        var knownIDs = admittedPhotoIDs.union(pendingSponsoredPhotos.map(\.id))

        for photo in photos where knownIDs.insert(photo.id).inserted {
            pendingSponsoredPhotos.append(photo)
        }

        insertPendingSponsoredPhotosIfPossible()
    }

    private func insertPendingSponsoredPhotosIfPossible() {
        guard isSponsoredLoadingActive, furthestReachedItemID != nil else {
            return
        }

        var draftItems = feedItems
        var draftAdmittedPhotoIDs = admittedPhotoIDs
        var remainingPhotos = pendingSponsoredPhotos
        var didInsert = false

        guard let currentVisibleIndex = currentVisibleIndex(in: draftItems),
              let furthestReachedIndex = furthestReachedIndex(in: draftItems) else {
            return
        }

        while let photo = remainingPhotos.first {
            guard !draftAdmittedPhotoIDs.contains(photo.id) else {
                _ = remainingPhotos.popFirst()
                continue
            }

            guard
                let insertionIndex = sponsoredInsertionPolicy.insertionIndex(
                    in: draftItems.values,
                    currentVisibleIndex: furthestReachedIndex
                ),
                sponsoredInsertionPolicy.isInsertionSafe(
                    at: insertionIndex,
                    currentVisibleIndex: currentVisibleIndex,
                    isImmediateInsertionOffscreenSafe: isImmediateInsertionOffscreenSafe
                )
            else {
                break
            }

            _ = remainingPhotos.popFirst()
            draftAdmittedPhotoIDs.insert(photo.id)

            let item = TodayFeedItem.sponsored(photo)
            draftItems[item.id] = item

            let appendedIndex = draftItems.count - 1
            draftItems.moveSubrange(appendedIndex..<draftItems.count, to: insertionIndex)
            didInsert = true
        }

        pendingSponsoredPhotos = remainingPhotos

        guard didInsert else {
            return
        }

        admittedPhotoIDs = draftAdmittedPhotoIDs
        feedItems = draftItems
    }

    private func itemIndex(for id: TodayFeedItem.ID) -> Int? {
        feedItems.index(forKey: id)
    }

    private func currentVisibleIndex(in items: OrderedDictionary<TodayFeedItem.ID, TodayFeedItem>) -> Int? {
        guard let currentVisibleItemID else {
            return nil
        }

        return items.index(forKey: currentVisibleItemID)
    }

    private func furthestReachedIndex(in items: OrderedDictionary<TodayFeedItem.ID, TodayFeedItem>) -> Int? {
        guard let furthestReachedItemID else {
            return nil
        }

        return items.index(forKey: furthestReachedItemID)
    }
}
