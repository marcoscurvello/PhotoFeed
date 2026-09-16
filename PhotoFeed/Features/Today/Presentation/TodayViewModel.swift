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
        static let defaultPageSize = 10
    }

    enum State: Equatable {
        case ready
        case loading
        case failed
    }

    private let repository: any PhotosRepository
    private let sponsoredCoordinator: SponsoredCoordinator
    private let sponsoredInsertionPolicy: SponsoredInsertionPolicy
    private let sponsoredConfiguration: SponsoredCoordinatorConfiguration

    private(set) var items: [TodayFeedItem] = []
    private(set) var state: State = .ready

    @ObservationIgnored
    private var admittedPhotoIDs: Set<Photo.ID> = []

    @ObservationIgnored
    private var photoStyles: [Photo.ID: PhotoCardStyle] = [:]

    @ObservationIgnored
    private var pendingSponsoredPhotos: [Photo] = []

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

        guard let id, let visibleIndex = items.firstIndex(where: { $0.id == id }) else {
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

        if items.isEmpty {
            guard nextPage == 1, bottomVisibleItemID == nil else {
                return
            }
        } else {
            guard bottomVisibleItemID == items.last?.id else {
                return
            }
        }

        await load(page: nextPage)
    }

    func retry() async {
        guard case .failed = state, let nextPage else {
            return
        }

        await load(page: nextPage)
    }

    func photoStyle(for item: TodayFeedItem) -> PhotoCardStyle {
        guard case .organic(let photo) = item else {
            return .card
        }

        return photoStyles[photo.id] ?? .card
    }

    private func load(page: Int) async {
        state = .loading

        do {
            let photoPage = try await repository.photos(page: page, perPage: Constants.defaultPageSize)

            guard !Task.isCancelled else {
                state = .ready
                return
            }

            appendOrganicPhotos(photoPage.photos)
            nextPage = photoPage.nextPage

            state = .ready

            insertPendingSponsoredPhotosIfPossible()
            replenishSponsoredPhotosIfNeeded()
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        switch HTTPRequestFailureClassification(error) {
            case .cancelled:
                state = .ready

            case .potentiallyTransient(_),
                 .nonTransient,
                 .unknown:
                state = .failed
        }
    }

    private func appendOrganicPhotos(_ photos: [Photo]) {
        var draftItems = items
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

            draftItems.append(.organic(photo))
        }

        guard !admittedIDs.isEmpty else {
            return
        }

        pendingSponsoredPhotos.removeAll { admittedIDs.contains($0.id) }
        admittedPhotoIDs = draftAdmittedPhotoIDs
        photoStyles = draftPhotoStyles
        items = draftItems
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

        var draftItems = items
        var draftAdmittedPhotoIDs = admittedPhotoIDs
        var remainingPhotos = pendingSponsoredPhotos[...]
        var didInsert = false

        guard let currentVisibleIndex = currentVisibleIndex(in: draftItems),
              let furthestReachedIndex = furthestReachedIndex(in: draftItems) else {
            return
        }

        while let photo = remainingPhotos.first {
            guard !draftAdmittedPhotoIDs.contains(photo.id) else {
                remainingPhotos.removeFirst()
                continue
            }

            guard
                let insertionIndex = sponsoredInsertionPolicy.insertionIndex(
                    in: draftItems,
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

            remainingPhotos.removeFirst()
            draftAdmittedPhotoIDs.insert(photo.id)
            draftItems.insert(.sponsored(photo), at: insertionIndex)
            didInsert = true
        }

        pendingSponsoredPhotos = Array(remainingPhotos)

        guard didInsert else {
            return
        }

        admittedPhotoIDs = draftAdmittedPhotoIDs
        items = draftItems
    }

    private var furthestReachedIndex: Int? {
        furthestReachedIndex(in: items)
    }

    private func currentVisibleIndex(in items: [TodayFeedItem]) -> Int? {
        guard let currentVisibleItemID else {
            return nil
        }

        return items.firstIndex { $0.id == currentVisibleItemID }
    }

    private func furthestReachedIndex(in items: [TodayFeedItem]) -> Int? {
        guard let furthestReachedItemID else {
            return nil
        }

        return items.firstIndex { $0.id == furthestReachedItemID }
    }
}
