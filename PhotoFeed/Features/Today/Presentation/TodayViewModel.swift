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
    private let sponsoredRequestCount: Int

    private(set) var items: [TodayFeedItem] = []
    private(set) var state: State = .ready

    private var admittedPhotoIDs: Set<Photo.ID> = []
    private var currentVisibleItemID: TodayFeedItem.ID?
    private var furthestReachedItemID: TodayFeedItem.ID?
    private var isSponsoredLoadingActive = false
    private var nextPage: Int? = 1

    @ObservationIgnored
    private lazy var sponsoredCoordinator = SponsoredCoordinator(
        repository: repository,
        configuration: .init(requestBatchSize: sponsoredRequestCount),
        isEligible: { [weak self] photo in
            guard let self else { return false }
            return !self.admittedPhotoIDs.contains(photo.id)
        },
        onCandidatesAvailable: { [weak self] in
            self?.insertSponsoredCandidatesIfPossible()
            self?.reconcileSponsoredSupply()
        }
    )

    init(
        repository: any PhotosRepository,
        insertionPolicy: SponsoredInsertionPolicy = SponsoredInsertionPolicy(),
        sponsoredRequestCount: Int = 3
    ) {
        self.repository = repository
        self.insertionPolicy = insertionPolicy
        self.sponsoredRequestCount = sponsoredRequestCount
    }

    func setSponsoredLoadingActive(_ isActive: Bool) {
        isSponsoredLoadingActive = isActive
        if isActive {
            sponsoredCoordinator.activate()
            reconcileSponsoredSupply()
        } else {
            currentVisibleItemID = nil
            sponsoredCoordinator.deactivate()
        }
    }

    func updateCurrentVisibleItem(_ id: TodayFeedItem.ID?) {
        guard isSponsoredLoadingActive else {
            currentVisibleItemID = nil
            return
        }

        currentVisibleItemID = id
        guard let id, let visibleIndex = items.firstIndex(where: { $0.id == id }) else {
            reconcileSponsoredSupply()
            return
        }

        if let furthestReachedItemID,
           let furthestIndex = items.firstIndex(where: { $0.id == furthestReachedItemID }),
           furthestIndex >= visibleIndex {
            insertSponsoredCandidatesIfPossible()
            reconcileSponsoredSupply()
            return
        }

        furthestReachedItemID = id
        insertSponsoredCandidatesIfPossible()
        reconcileSponsoredSupply()
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

        reconcileSponsoredSupply()
        await loadOrganicPhotos(page: page)
    }

    private func loadOrganicPhotos(page: Int) async {
        do {
            let photos = try await repository.photos(page: page, perPage: Constants.pageSize)

            guard !Task.isCancelled else {
                state = .ready
                reconcileSponsoredSupply()
                return
            }

            guard !photos.isEmpty else {
                nextPage = nil
                state = .ready
                reconcileSponsoredSupply()
                return
            }

            appendOrganicPhotos(photos)

            nextPage = photos.count < Constants.pageSize ? nil : page + 1
            state = .ready
            insertSponsoredCandidatesIfPossible()
            reconcileSponsoredSupply()

        } catch is CancellationError {
            state = .ready
            reconcileSponsoredSupply()
        } catch let error as URLError where error.code == .cancelled {
            state = .ready
            reconcileSponsoredSupply()
        } catch {
            state = Task.isCancelled
            ? .ready
            : .failed(error.localizedDescription)
            reconcileSponsoredSupply()
        }
    }

    private func appendOrganicPhotos(_ photos: [Photo]) {
        let newItems = photos.compactMap { photo -> TodayFeedItem? in
            guard admittedPhotoIDs.insert(photo.id).inserted else {
                return nil
            }

            sponsoredCoordinator.removeCandidate(withID: photo.id)
            return .organic(photo)
        }
        items.append(contentsOf: newItems)
    }

    private func insertSponsoredCandidatesIfPossible() {
        guard isSponsoredLoadingActive, currentVisibleIndex != nil, let furthestReachedIndex else {
            return
        }

        while let insertionIndex = insertionPolicy.insertionIndex(in: items, currentVisibleIndex: furthestReachedIndex),
              let photo = sponsoredCoordinator.takeNextCandidate() {

            guard admittedPhotoIDs.insert(photo.id).inserted else { continue }
            items.insert(.sponsored(photo), at: insertionIndex)
        }
    }

    private func reconcileSponsoredSupply() {
        let canSeedInitialSupply = items.isEmpty && state == .loading && nextPage != nil
        let hasFuturePlacement = furthestReachedIndex.flatMap {
            insertionPolicy.insertionIndex(in: items, currentVisibleIndex: $0)
        } != nil
        let hasSupplyOpportunity = canSeedInitialSupply || hasFuturePlacement || (nextPage != nil && !items.isEmpty)
        let effectiveTarget = nextPage == nil ? terminalTargetCoverage : nil

        sponsoredCoordinator.reconcile(
            coverage: sponsoredCoverage,
            targetCoverage: effectiveTarget,
            hasSupplyOpportunity: hasSupplyOpportunity
        )
    }

    private var sponsoredCoverage: Int {
        sponsoredCoordinator.candidateCount + sponsoredItemsAheadOfProgress
    }

    private var sponsoredItemsAheadOfProgress: Int {
        guard let furthestReachedIndex else { return 0 }
        return items[items.index(after: furthestReachedIndex)...].reduce(into: 0) {
            $0 += $1.isSponsored ? 1 : 0
        }
    }

    private var terminalTargetCoverage: Int {
        min(sponsoredCoordinator.maximumCoverage, sponsoredItemsAheadOfProgress + terminalInsertionCapacity)
    }

    private var terminalInsertionCapacity: Int {
        guard let furthestReachedIndex,
              var insertionIndex = insertionPolicy.insertionIndex(in: items, currentVisibleIndex: furthestReachedIndex) else {
            return 0
        }

        var capacity = 1

        while capacity < sponsoredCoordinator.maximumCoverage {
            var organicItemsAfterLastSponsor = 0
            var nextInsertionIndex: Int?

            for index in insertionIndex..<items.endIndex where !items[index].isSponsored {
                organicItemsAfterLastSponsor += 1

                if organicItemsAfterLastSponsor == insertionPolicy.organicItemsBetweenSponsored {
                    nextInsertionIndex = items.index(after: index)
                    break
                }
            }

            guard let nextInsertionIndex else { break }
            capacity += 1
            insertionIndex = nextInsertionIndex
        }

        return capacity
    }

    private var currentVisibleIndex: Int? {
        guard let currentVisibleItemID else { return nil }
        return items.firstIndex(where: { $0.id == currentVisibleItemID })
    }

    private var furthestReachedIndex: Int? {
        guard let furthestReachedItemID else { return nil }
        return items.firstIndex(where: { $0.id == furthestReachedItemID })
    }
}
