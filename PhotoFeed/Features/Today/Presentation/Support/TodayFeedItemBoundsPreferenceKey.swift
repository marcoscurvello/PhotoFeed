//
//  TodayFeedItemBoundsPreferenceKey.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 14/09/2026.
//

import SwiftUI

struct TodayFeedItemBoundsPreferenceKey: PreferenceKey {

    static let defaultValue: [TodayFeedItem.ID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TodayFeedItem.ID: Anchor<CGRect>],
        nextValue: () -> [TodayFeedItem.ID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}
