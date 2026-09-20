//
//  DetailHero.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailHero: View {

    private enum Constants {
        static let defaultAspectRatio = 0.82
        static let aspectRatioThreshold = 1.2
    }

    private enum Presentation {
        case natural
        case immersiveLandscape
    }

    let photo: Photo
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .containerRelativeFrame(.horizontal)
            .aspectRatio(heroAspectRatio, contentMode: .fit)
            .overlay {
                DetailHeroMedia(
                    imageURL: photo.imageURLs.regular,
                    imagePipeline: imagePipeline,
                    blurHash: photo.blurHash,
                    photoAspectRatio: photoAspectRatio,
                    contentMode: heroContentMode
                )
            }
            .overlay(alignment: .bottomLeading) {
                DetailHeroMetadata(
                    description: photo.description,
                    photographerName: photo.user.name
                )
            }
    }

    private var photoAspectRatio: CGFloat {
        photo.aspectRatio ?? Constants.defaultAspectRatio
    }

    private var presentation: Presentation {
        photoAspectRatio > Constants.aspectRatioThreshold
        ? .immersiveLandscape
        : .natural
    }

    private var heroAspectRatio: CGFloat {
        switch presentation {
            case .natural: photoAspectRatio
            case .immersiveLandscape: Constants.defaultAspectRatio
        }
    }

    private var heroContentMode: ContentMode {
        switch presentation {
            case .natural: .fit
            case .immersiveLandscape: .fill
        }
    }
}

#if DEBUG
#Preview {
    ScrollView {
        DetailHero(
            photo: PhotoPreviewFixtures.detailPhoto,
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
    .ignoresSafeArea(.container, edges: .top)
}
#endif
