//
//  SponsoredCoordinatorConfiguration.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 10/09/2026.
//

import Foundation

nonisolated struct SponsoredCoordinatorConfiguration: Sendable {

    let targetCoverage: Int
    let lowWatermark: Int
    let requestBatchSize: Int
    let maximumRequestsPerEpisode: Int

    init(
        targetCoverage: Int = 3,
        lowWatermark: Int = 1,
        requestBatchSize: Int = 3,
        maximumRequestsPerEpisode: Int = 3
    ) {
        precondition(targetCoverage > 0)
        precondition(lowWatermark >= 0 && lowWatermark < targetCoverage)
        precondition((1...30).contains(requestBatchSize))
        precondition(maximumRequestsPerEpisode > 0)
        self.targetCoverage = targetCoverage
        self.lowWatermark = lowWatermark
        self.requestBatchSize = requestBatchSize
        self.maximumRequestsPerEpisode = maximumRequestsPerEpisode
    }
}
