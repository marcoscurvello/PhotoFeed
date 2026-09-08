//
//  TodayPhotoRow.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct TodayPhotoRow: View {

    let item: TodayFeedItem
    let style: PhotoCardStyle
    let imagePipeline: RemoteImagePipeline
    let action: () -> Void

    var body: some View {
        PhotoCardView(
            photo: item.photo,
            imagePipeline: imagePipeline,
            style: style,
            isSponsored: item.isSponsored,
            action: action
        )
        .padding(.horizontal, style.horizontalPadding)
        .containerRelativeFrame(.horizontal)
    }
}

#Preview("Card") {
    ScrollView {
        TodayPhotoRow(
            item: .organic(TodayPreviewFixtures.photo),
            style: .card,
            imagePipeline: TodayPreviewFixtures.imagePipeline,
            action: {}
        )
    }
}

#Preview("Full Bleed") {
    ScrollView {
        TodayPhotoRow(
            item: .organic(TodayPreviewFixtures.photo),
            style: .fullBleed,
            imagePipeline: TodayPreviewFixtures.imagePipeline,
            action: {}
        )
    }
}
