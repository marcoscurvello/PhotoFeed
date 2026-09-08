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
    let isSponsored: Bool
    let action: () -> Void

    init(
        photo: Photo,
        imagePipeline: RemoteImagePipeline,
        isSponsored: Bool = false,
        action: @escaping () -> Void
    ) {
        self.photo = photo
        self.imagePipeline = imagePipeline
        self.isSponsored = isSponsored
        self.action = action
    }

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 460)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                metadata
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 460)
            .overlay(alignment: .topTrailing) {
                if isSponsored {
                    Text("Sponsored")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(maxWidth: .infinity)
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
        let attribution = photo.description.map { "\($0), photo by \(photo.user.name)" } ?? "Photo by \(photo.user.name)"

        return isSponsored ? "Sponsored, \(attribution)" : attribution
    }
}

#Preview("Organic") {
    PhotoCardView(
        photo: TodayPreviewFixtures.photo,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        action: {}
    )
    .padding()
}

#Preview("Sponsored") {
    PhotoCardView(
        photo: TodayPreviewFixtures.photo,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        isSponsored: true,
        action: {}
    )
    .padding()
}
