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
        static let defaultPageSize = 20
    }

    enum State: Equatable {
        case ready
        case loading
        case failed(String)
    }

    private let repository: any PhotosRepository
    private let sponsoredCoordinator: SponsoredCoordinator
    private let sponsoredInsertionPolicy: SponsoredInsertionPolicy
    private let sponsoredConfiguration: SponsoredCoordinatorConfiguration

    private(set) var items: [TodayFeedItem] = []
    private(set) var state: State = .ready

    private var admittedPhotoIDs: Set<Photo.ID> = []
    private var photoStyles: [Photo.ID: PhotoCardStyle] = [:]
    private var pendingSponsoredPhotos: [Photo] = []

    private var currentVisibleItemID: TodayFeedItem.ID?
    private var furthestReachedItemID: TodayFeedItem.ID?

    private var isSponsoredLoadingActive = false
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
            sponsoredTask?.cancel()
        }
    }

    func updateCurrentVisibleItem(_ id: TodayFeedItem.ID?) {
        guard isSponsoredLoadingActive else {
            currentVisibleItemID = nil
            return
        }

        guard currentVisibleItemID != id else {
            return
        }

        currentVisibleItemID = id

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
                state = .failed(error.localizedDescription)
        }
    }

    private func appendOrganicPhotos(_ photos: [Photo]) {
        for photo in photos {
            guard admittedPhotoIDs.insert(photo.id).inserted else {
                continue
            }

            pendingSponsoredPhotos.removeAll {
                $0.id == photo.id
            }

            let organicOrdinal = photoStyles.count

            photoStyles[photo.id] = organicOrdinal.isMultiple(of: 4)
            ? .fullBleed
            : .card

            items.append(.organic(photo))
        }
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
        guard isSponsoredLoadingActive, let insertionBoundary = furthestReachedIndex else {
            return
        }

        while let photo = pendingSponsoredPhotos.first {
            guard let insertionIndex = sponsoredInsertionPolicy.insertionIndex(in: items, currentVisibleIndex: insertionBoundary) else {
                return
            }

            pendingSponsoredPhotos.removeFirst()

            guard admittedPhotoIDs.insert(photo.id).inserted else {
                continue
            }

            items.insert(.sponsored(photo), at: insertionIndex)
        }
    }

    private var furthestReachedIndex: Int? {
        guard let furthestReachedItemID else {
            return nil
        }

        return items.firstIndex { $0.id == furthestReachedItemID }
    }
}
