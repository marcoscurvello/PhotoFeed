//
//  DetailHeroMedia.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailHeroMedia: View {

    let imageURL: URL
    let imagePipeline: RemoteImagePipeline
    let blurHash: String?
    let photoAspectRatio: CGFloat
    let contentMode: ContentMode

    var body: some View {
        RemoteImageView(
            url: imageURL,
            pipeline: imagePipeline,
            blurHash: blurHash,
            placeholderAspectRatio: photoAspectRatio,
            contentMode: contentMode
        ) {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    ProgressView()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.18), location: 0.72),
                    .init(color: .black.opacity(0.72), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .clipped()
        .visualEffect { content, geometryProxy in
            let frame = geometryProxy.frame(in: .scrollView(axis: .vertical))
            let overscroll = max(frame.minY, 0)
            let height = max(frame.height, 1)
            let scale = 1 + overscroll / height

            return content
                .scaleEffect(scale, anchor: .bottom)
        }
    }
}

#Preview {
    ScrollView {
        DetailHeroMedia(
            imageURL: PhotoPreviewFixtures.detailPhoto.imageURLs.regular,
            imagePipeline: PhotoPreviewFixtures.imagePipeline,
            blurHash: PhotoPreviewFixtures.detailPhoto.blurHash,
            photoAspectRatio: CGFloat(PhotoPreviewFixtures.detailPhoto.aspectRatio),
            contentMode: .fit
        )
        .frame(height: 460)
    }
}
