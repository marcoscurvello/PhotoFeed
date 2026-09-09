//
//  PhotoStatisticsDTO.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct PhotoStatisticsDTO: Decodable, Sendable {

    let id: String
    let views: MetricDTO
    let likes: MetricDTO?
    let downloads: MetricDTO

    nonisolated struct MetricDTO: Decodable, Sendable {
        let total: Int
        let historical: HistoricalDTO
    }

    nonisolated struct HistoricalDTO: Decodable, Sendable {
        let change: Int
        let quantity: Int
    }
}
