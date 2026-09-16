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
    let photographerName: String
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        let userPhotosState = viewModel.userPhotosState
        let additionalUserPhotos = userPhotosState.loadedValue ?? []

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

                case .failed:
                    DetailUserPhotosFailure(viewModel: viewModel)
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

private struct DetailUserPhotosFailure: View {

    let viewModel: DetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("More photos couldn't be loaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await viewModel.retryUserPhotos()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview("Loaded user photos") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel()

    DetailUserPhotosSection(
        viewModel: viewModel,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name,
        imagePipeline: PhotoPreviewFixtures.imagePipeline
    )
    .task { await viewModel.load() }
}

#Preview("User photos loading") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(
        userPhotosBehavior: .loading
    )

    DetailUserPhotosSection(
        viewModel: viewModel,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name,
        imagePipeline: PhotoPreviewFixtures.imagePipeline
    )
    .task { await viewModel.load() }
}

#Preview("User photos failure") {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(
        userPhotosBehavior: .failure
    )

    DetailUserPhotosSection(
        viewModel: viewModel,
        photographerName: PhotoPreviewFixtures.detailPhoto.user.name,
        imagePipeline: PhotoPreviewFixtures.imagePipeline
    )
    .task { await viewModel.load() }
}
