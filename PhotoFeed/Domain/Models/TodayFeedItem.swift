//
//  TodayFeedItem.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum TodayFeedItem: Identifiable, Hashable, Sendable {

    nonisolated enum ID: Hashable, Sendable {
        case organic(Photo.ID)
        case sponsored(Photo.ID)
    }

    case organic(Photo)
    case sponsored(Photo)

    var id: ID {
        switch self {
        case .organic(let photo): .organic(photo.id)
        case .sponsored(let photo): .sponsored(photo.id)
        }
    }

    var photo: Photo {
        switch self {
        case .organic(let photo), .sponsored(let photo):
            photo
        }
    }

    var isSponsored: Bool {
        if case .sponsored = self {
            return true
        }

        return false
    }
}
