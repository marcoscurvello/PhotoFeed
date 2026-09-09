//
//  PhotoStatistics.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct PhotoStatistics: Hashable, Sendable {

    nonisolated struct Metric: Hashable, Sendable {
        let total: Int
        let change: Int
        let periodDays: Int
    }

    let views: Metric
    let likes: Metric?
    let downloads: Metric
}
