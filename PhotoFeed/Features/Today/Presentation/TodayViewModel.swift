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

    private let repository: any PhotosRepository
    private let insertionPolicy: SponsoredInsertionPolicy
    private let sponsoredConfiguration: SponsoredCoordinatorConfiguration
    private let sponsoredCoordinator: SponsoredCoordinator

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
        self.insertionPolicy = insertionPolicy
        self.sponsoredConfiguration = sponsoredConfiguration

        self.sponsoredCoordinator = SponsoredCoordinator(repository: repository, configuration: sponsoredConfiguration)
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

    func photoStyle(for item: TodayFeedItem) -> PhotoCardStyle {
        guard case .organic(let photo) = item else {
            return .card
        }

        return photoStyles[photo.id] ?? .card
    }

    private func loadPage(_ page: Int) async {
        state = .loading
        await loadOrganicPhotos(page: page)
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

                insertPendingSponsoredPhotosIfPossible()
                replenishSponsoredPhotosIfNeeded()
                return
            }

            appendOrganicPhotos(photos)

            nextPage = photos.count < Constants.pageSize
            ? nil
            : page + 1

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
            guard let insertionIndex = insertionPolicy.insertionIndex(in: items, currentVisibleIndex: insertionBoundary) else {
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
