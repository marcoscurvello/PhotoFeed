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
    let style: PhotoCardStyle
    let isSponsored: Bool
    let action: () -> Void

    init(
        photo: Photo,
        imagePipeline: RemoteImagePipeline,
        style: PhotoCardStyle = .card,
        isSponsored: Bool = false,
        action: @escaping () -> Void
    ) {
        self.photo = photo
        self.imagePipeline = imagePipeline
        self.style = style
        self.isSponsored = isSponsored
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(style.aspectRatio, contentMode: .fit)
                .overlay {
                    RemoteImageView(url: photo.imageURLs.regular, pipeline: imagePipeline) {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    metadata
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .overlay(alignment: .topTrailing) {
                    if isSponsored {
                        sponsoredBadge
                            .padding(style.sponsoredBadgePadding)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
                .contentShape(Rectangle())
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
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Photo by \(photo.user.name)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sponsoredBadge: some View {
        Text("Sponsored")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
    }

    private var accessibilityLabel: String {
        let attribution = photo.description.map { "\($0), photo by \(photo.user.name)" } ?? "Photo by \(photo.user.name)"
        return isSponsored ? "Sponsored, \(attribution)" : attribution
    }
}

#Preview("Card") {
    PhotoCardView(
        photo: TodayPreviewFixtures.photo,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        style: .card,
        action: {}
    )
    .padding(.horizontal, 20)
}

#Preview("Full Bleed") {
    PhotoCardView(
        photo: TodayPreviewFixtures.photo,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        style: .fullBleed,
        action: {}
    )
}

#Preview("Sponsored") {
    PhotoCardView(
        photo: TodayPreviewFixtures.photos[1],
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        style: .card,
        isSponsored: true,
        action: {}
    )
    .padding(.horizontal, 20)
}
