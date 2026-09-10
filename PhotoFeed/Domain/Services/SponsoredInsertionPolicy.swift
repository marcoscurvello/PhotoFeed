//
//  SponsoredInsertionPolicy.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct SponsoredInsertionPolicy: Sendable {

    let organicItemsBetweenSponsored: Int

    init(organicItemsBetweenSponsored: Int = 4) {
        precondition(organicItemsBetweenSponsored > 0)
        self.organicItemsBetweenSponsored = organicItemsBetweenSponsored
    }

    func insertionIndex(in items: [TodayFeedItem], currentVisibleIndex: Int) -> Int? {
        guard !items.isEmpty else {
            return nil
        }

        let safeInsertionIndex = min(max(currentVisibleIndex + 1, 0), items.count)

        guard let lastSponsoredIndex = items.lastIndex(where: \.isSponsored) else {
            return safeInsertionIndex
        }

        var organicCount = 0

        for index in items.index(after: lastSponsoredIndex)..<items.endIndex {
            guard !items[index].isSponsored else {
                continue
            }

            organicCount += 1

            if organicCount == organicItemsBetweenSponsored {
                let scheduledIndex = items.index(after: index)
                return max(scheduledIndex, safeInsertionIndex)
            }
        }

        return nil
    }
}
