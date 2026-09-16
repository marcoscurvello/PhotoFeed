//
//  DetailHero.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailHero: View {

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
        guard photo.width > 0, photo.height > 0 else {
            return 0.82
        }

        return CGFloat(photo.width) / CGFloat(photo.height)
    }

    private var presentation: Presentation {
        photoAspectRatio > 1.2 ? .immersiveLandscape : .natural
    }

    private var heroAspectRatio: CGFloat {
        switch presentation {
            case .natural: photoAspectRatio
            case .immersiveLandscape: 0.82
        }
    }

    private var heroContentMode: ContentMode {
        switch presentation {
            case .natural: .fit
            case .immersiveLandscape: .fill
        }
    }
}

#Preview {
    ScrollView {
        DetailHero(
            photo: PhotoPreviewFixtures.detailPhoto,
            imagePipeline: PhotoPreviewFixtures.imagePipeline
        )
    }
    .ignoresSafeArea(.container, edges: .top)
}
