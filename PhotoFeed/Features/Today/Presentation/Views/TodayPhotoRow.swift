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
    let transitionNamespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        PhotoCardView(
            photo: item.photo,
            imagePipeline: imagePipeline,
            style: style,
            isSponsored: item.isSponsored,
            action: action
        )
        .matchedTransitionSource(
            id: item.id,
            in: transitionNamespace
        ) { source in
            source
                .clipShape(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                )
        }
        .padding(.horizontal, style.horizontalPadding)
        .containerRelativeFrame(.horizontal)
    }
}

#Preview("Card") {
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        TodayPhotoRow(
            item: .organic(TodayPreviewFixtures.photo),
            style: .card,
            imagePipeline: TodayPreviewFixtures.imagePipeline,
            transitionNamespace: transitionNamespace,
            action: {}
        )
    }
}

#Preview("Full Bleed") {
    @Previewable @Namespace var transitionNamespace

    ScrollView {
        TodayPhotoRow(
            item: .organic(TodayPreviewFixtures.photo),
            style: .fullBleed,
            imagePipeline: TodayPreviewFixtures.imagePipeline,
            transitionNamespace: transitionNamespace,
            action: {}
        )
    }
}
