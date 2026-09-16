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
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens photo viewer")
    }

    private var accessibilityLabel: LocalizedStringResource {
        if let description = photo.description {
            LocalizedStringResource(
                "\(description), photo by \(photo.user.name)",
                comment: "Accessibility label for a photographer's photo. The first placeholder is the photo description and the second is the photographer's name."
            )
        } else {
            LocalizedStringResource(
                "Photo by \(photo.user.name)",
                comment: "Accessibility label for a photographer's photo without a description. The placeholder is the photographer's name."
            )
        }
    }
}

#Preview {
    DetailUserPhoto(
        photo: PhotoPreviewFixtures.detailUserPhotos[1],
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        onSelect: {}
    )
    .padding()
}
