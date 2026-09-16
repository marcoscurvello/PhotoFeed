//
//  PhotoViewerPager.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct PhotoViewerPager: View {

    let photos: [Photo]
    let initialPhotoID: Photo.ID
    let imagePipeline: RemoteImagePipeline

    @Binding var isZoomed: Bool
    let isDismissing: Bool

    @State private var selectedPhotoID: Photo.ID?

    init(
        photos: [Photo],
        initialPhotoID: Photo.ID,
        imagePipeline: RemoteImagePipeline,
        isZoomed: Binding<Bool>,
        isDismissing: Bool
    ) {
        self.photos = photos
        self.initialPhotoID = initialPhotoID
        self.imagePipeline = imagePipeline
        _isZoomed = isZoomed
        self.isDismissing = isDismissing
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    var body: some View {
        let currentPosition = selectedPhotoID.flatMap { selectedPhotoID in
            photos.firstIndex(where: { $0.id == selectedPhotoID }).map { $0 + 1 }
        }

        ZStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(photos) { photo in
                        ZoomablePhotoView(
                            photo: photo,
                            imagePipeline: imagePipeline,
                            isSelected: selectedPhotoID == photo.id,
                            isZoomed: $isZoomed
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(photo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedPhotoID, anchor: .center)
            .scrollDisabled(isZoomed || isDismissing)

            PhotoViewerControls(
                currentPosition: currentPosition,
                totalCount: photos.count
            )
        }
    }
}

#Preview {
    @Previewable @State var isZoomed = false

    PhotoViewerPager(
        photos: TodayPreviewFixtures.photos,
        initialPhotoID: TodayPreviewFixtures.photo.id,
        imagePipeline: TodayPreviewFixtures.imagePipeline,
        isZoomed: $isZoomed,
        isDismissing: false
    )
    .background(.black)
}
