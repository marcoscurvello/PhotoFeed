//
//  PhotoCardStyle.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

nonisolated enum PhotoCardStyle: Sendable {

    case card
    case fullBleed

    var horizontalPadding: CGFloat {
        switch self {
        case .card: 20
        case .fullBleed: 0
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .card: 0.78
        case .fullBleed: 0.86
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .card: 28
        case .fullBleed: 0
        }
    }

    var sponsoredBadgePadding: CGFloat {
        switch self {
        case .card: 16
        case .fullBleed: 20
        }
    }
}
