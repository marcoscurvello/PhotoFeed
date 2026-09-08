//
//  PhotoCardView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct PhotoCardView: View {

    let photo: Photo
    let imagePipeline: RemoteImagePipeline
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RemoteImageView(url: photo.imageURLs.regular, pipeline: imagePipeline) {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 460)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                metadata
                    .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = photo.description {
                Text(description)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Text("Photo by \(photo.user.name)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var accessibilityLabel: String {
        if let description = photo.description {
            return "\(description), photo by \(photo.user.name)"
        }

        return "Photo by \(photo.user.name)"
    }
}

#Preview {
    PhotoCardView(
        photo: TodayPreviewFixtures.photo,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        action: {}
    )
    .padding()
}
