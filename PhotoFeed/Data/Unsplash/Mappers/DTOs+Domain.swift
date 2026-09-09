//
//  PhotoDTO+Photo.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated extension PhotoDTO {
    var domainModel: Photo {
        Photo(
            id: Photo.ID(rawValue: id),
            width: width,
            height: height,
            colorHex: color,
            description: description ?? altDescription,
            imageURLs: Photo.ImageURLs(
                full: urls.full,
                regular: urls.regular,
                small: urls.small,
                thumbnail: urls.thumb
            ),
            user: user.domainModel,
            webpageURL: links.html
        )
    }
}

nonisolated extension UserDTO {
    var domainModel: User {
        User(
            id: User.ID(rawValue: id),
            username: username,
            name: name ?? username,
            avatarURL: profileImage.medium,
            webpageURL: links.html
        )
    }
}

nonisolated extension PhotoStatisticsDTO {
    var domainModel: PhotoStatistics {
        PhotoStatistics(
            views: views.domainModel,
            likes: likes?.domainModel,
            downloads: downloads.domainModel
        )
    }
}

nonisolated private extension PhotoStatisticsDTO.MetricDTO {
    var domainModel: PhotoStatistics.Metric {
        PhotoStatistics.Metric(
            total: total,
            change: historical.change,
            periodDays: historical.quantity
        )
    }
}
