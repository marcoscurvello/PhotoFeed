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

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoID: Photo.ID?
    @State private var dismissOffset: CGFloat = 0
    @State private var isZoomed = false
    @State private var isDismissing = false

    let initialPhotoID: Photo.ID

    init(
        photos: [Photo],
        initialPhotoID: Photo.ID,
        imagePipeline: RemoteImagePipeline
    ) {
        self.photos = photos
        self.imagePipeline = imagePipeline
        self.initialPhotoID = initialPhotoID
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

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

                controls
            }
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

    private func resetDismissOffset() {
        withAnimation(.snappy) {
            dismissOffset = 0
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")

                Spacer()

                if let counter {
                    Text(counter)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .safeAreaPadding(.top, 8)
    }

    private var counter: String? {
        guard let selectedPhotoID,
              let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return nil
        }

        return "\(index + 1) / \(photos.count)"
    }
}

#Preview {
    PhotoViewerView(
        photos: TodayPreviewFixtures.photos,
        initialPhotoID: TodayPreviewFixtures.photo.id,
        imagePipeline: TodayPreviewFixtures.imagePipeline
    )
}
