//
//  DetailUserPhotosSection.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailUserPhotosSection: View {

    @State private var selectedViewerPhoto: Photo?

    let viewModel: DetailViewModel
    let imagePipeline: RemoteImagePipeline
    let photographerName: String
    let usesSharedRetryNotice: Bool

    init(
        viewModel: DetailViewModel,
        imagePipeline: RemoteImagePipeline,
        photographerName: String,
        usesSharedRetryNotice: Bool = false
    ) {
        self.viewModel = viewModel
        self.imagePipeline = imagePipeline
        self.photographerName = photographerName
        self.usesSharedRetryNotice = usesSharedRetryNotice
    }

    var body: some View {
        let userPhotosState = viewModel.userPhotosState
        let additionalUserPhotos = userPhotosState.loadedValue ?? []

        if !usesSharedRetryNotice {
            VStack(alignment: .leading, spacing: 16) {

                Text("More by \(photographerName)")
                    .font(.title2.bold())
                    .lineLimit(2)
                    .padding(.horizontal, 20)

                switch userPhotosState {
                    case .loaded(let photos) where !photos.isEmpty:
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(photos) { photo in
                                    DetailUserPhoto(photo: photo, imagePipeline: imagePipeline) {
                                        selectedViewerPhoto = photo
                                    }
                                }
                            }
                        }
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                        .scrollIndicators(.hidden)

                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)

                    case .failed(let failure), .retrying(let failure):
                        DetailUserPhotosFailure(
                            failure: failure,
                            isRetrying: userPhotosState == .retrying(failure),
                            onRetry: { await viewModel.retryUserPhotos() }
                        )
                        .padding(.horizontal, 20)

                    case .loaded, .idle:
                        Text("No additional photos available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                }
            }
            .fullScreenCover(item: $selectedViewerPhoto) { photo in
                PhotoViewerView(
                    photos: additionalUserPhotos,
                    initialPhotoID: photo.id,
                    imagePipeline: imagePipeline
                )
            }
        }
    }
}

#Preview("Loaded user photos") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel()

    DetailUserPhotosSection(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name
    )
    .task { await viewModel.load() }
}

#Preview("User photos loading") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(userPhotosBehavior: .loading)

    DetailUserPhotosSection(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name
    )
    .task { await viewModel.load() }
}

#Preview("User photos failure") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(userPhotosBehavior: .failure)

    DetailUserPhotosSection(
        viewModel: viewModel,
        imagePipeline: PhotoPreviewFixtures.imagePipeline,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name
    )
    .task { await viewModel.load() }
}
