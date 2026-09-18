//
//  PhotoViewerView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 10/09/2026.
//

import SwiftUI

struct PhotoViewerView: View {

    private enum Constants {
        static let dismissThreshold: CGFloat = 120
        static let predictedDismissThreshold: CGFloat = 200
    }

    let photos: [Photo]
    let imagePipeline: RemoteImagePipeline
    let initialPhotoID: Photo.ID

    @Environment(\.dismiss) private var dismiss
    @State private var dismissOffset: CGFloat = 0
    @State private var isZoomed = false
    @State private var isDismissing = false

    init(
        photos: [Photo],
        initialPhotoID: Photo.ID,
        imagePipeline: RemoteImagePipeline
    ) {
        self.photos = photos
        self.imagePipeline = imagePipeline
        self.initialPhotoID = initialPhotoID
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            PhotoViewerPager(
                photos: photos,
                initialPhotoID: initialPhotoID,
                imagePipeline: imagePipeline,
                isZoomed: $isZoomed,
                isDismissing: isDismissing
            )
            .offset(y: dismissOffset)
        }
        .preferredColorScheme(.dark)
        .simultaneousGesture(
            dismissGesture,
            including: isZoomed ? .none : .all
        )
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let translation = value.translation

                if isDismissing {
                    dismissOffset = max(translation.height, 0)
                    return
                }

                guard
                    translation.height > 0,
                    abs(translation.height) > abs(translation.width)
                        else {
                    return
                }

                isDismissing = true
                dismissOffset = translation.height
            }
            .onEnded { value in
                guard isDismissing else {
                    return
                }

                let shouldDismiss =
                value.translation.height > Constants.dismissThreshold ||
                value.predictedEndTranslation.height > Constants.predictedDismissThreshold

                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.snappy) {
                        dismissOffset = 0
                    }

                    isDismissing = false
                }
            }
    }

}

#Preview {
    PhotoViewerView(
        photos: PhotoPreviewFixtures.detailUserPhotos,
        initialPhotoID: PhotoPreviewFixtures.detailPhoto.id,
        imagePipeline: PhotoPreviewFixtures.imagePipeline
    )
}
