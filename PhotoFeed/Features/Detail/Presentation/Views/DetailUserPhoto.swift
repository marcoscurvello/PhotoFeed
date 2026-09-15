//
//  DetailUserPhoto.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailUserPhoto: View {

    let photo: Photo
    let imagePipeline: RemoteImagePipeline
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
                .frame(width: 160, height: 205)
                .overlay {
                    RemoteImageView(url: photo.imageURLs.small, pipeline: imagePipeline) {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.description ?? "Photo by \(photo.user.name)")
        .accessibilityHint("Opens photo viewer")
    }
}

#Preview {
    DetailUserPhoto(
        photo: TodayPreviewFixtures.photos[1],
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        onSelect: {}
    )
    .padding()
}
