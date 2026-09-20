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
            request: RemoteImageRequest(url: imageURL, blurHash: blurHash),
            pipeline: imagePipeline,
            previewAspectRatio: photoAspectRatio,
            contentMode: contentMode
        )
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

#if DEBUG
#Preview {
    ScrollView {
        DetailHeroMedia(
            imageURL: PhotoPreviewFixtures.detailPhoto.imageURLs.regular,
            imagePipeline: PhotoPreviewFixtures.imagePipeline,
            blurHash: PhotoPreviewFixtures.detailPhoto.blurHash,
            photoAspectRatio: PhotoPreviewFixtures.detailPhoto.aspectRatio ?? 0.82,
            contentMode: .fit
        )
        .frame(height: 460)
    }
}
#endif
