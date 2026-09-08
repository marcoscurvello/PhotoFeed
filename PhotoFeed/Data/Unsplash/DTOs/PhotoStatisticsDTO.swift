//
//  PhotoStatisticsDTO.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct PhotoStatisticsDTO: Decodable, Sendable {
    let id: String
    let downloads: StatisticDTO
    let views: StatisticDTO
    let likes: StatisticDTO
}

nonisolated struct StatisticDTO: Decodable, Sendable {
    let total: Int
    let historical: HistoricalStatisticDTO
}

nonisolated struct HistoricalStatisticDTO: Decodable, Sendable {
    let change: Int
    let resolution: String
    let quantity: Int
    let values: [StatisticValueDTO]
}

nonisolated struct StatisticValueDTO: Decodable, Sendable {
    let date: String
    let value: Int
}
