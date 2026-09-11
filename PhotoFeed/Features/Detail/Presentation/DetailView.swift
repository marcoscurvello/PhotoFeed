//
//  DetailView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI

struct DetailView: View {

    private enum HeroPresentation {
        case natural
        case immersiveLandscape
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedViewerPhoto: Photo?
    @State private var viewModel: DetailViewModel

    let imagePipeline: RemoteImagePipeline

    init(viewModel: DetailViewModel, imagePipeline: RemoteImagePipeline) {
        _viewModel = State(initialValue: viewModel)
        self.imagePipeline = imagePipeline
    }

    var body: some View {
        detailScrollView
            .background(.background)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .safeAreaPadding(.top, 8)
            }
            .task {
                await viewModel.load()
            }
            .fullScreenCover(item: $selectedViewerPhoto) { photo in
                PhotoViewerView(
                    photos: additionalUserPhotos,
                    initialPhotoID: photo.id,
                    imagePipeline: imagePipeline
                )
            }
    }

    @ViewBuilder
    private var detailScrollView: some View {
        let scrollView = ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                detailsContent
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollIndicators(.hidden)

        if #available(iOS 26.0, *) {
            scrollView
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            scrollView
        }
    }

    private var hero: some View {
        Rectangle()
            .fill(.quaternary)
            .containerRelativeFrame(.horizontal)
            .aspectRatio(heroAspectRatio, contentMode: .fit)
            .overlay {
                heroMedia
            }
            .overlay(alignment: .bottomLeading) {
                heroMetadata
            }
    }

    private var photoAspectRatio: CGFloat {
        guard viewModel.photo.width > 0, viewModel.photo.height > 0 else {
            return 0.82
        }

        return CGFloat(viewModel.photo.width) / CGFloat(viewModel.photo.height)
    }

    private var heroPresentation: HeroPresentation {
        photoAspectRatio > 1.2 ? .immersiveLandscape : .natural
    }

    private var heroAspectRatio: CGFloat {
        switch heroPresentation {
        case .natural: photoAspectRatio
        case .immersiveLandscape: 0.82
        }
    }

    private var heroContentMode: ContentMode {
        switch heroPresentation {
        case .natural: .fit
        case .immersiveLandscape: .fill
        }
    }

    private var heroMedia: some View {
        RemoteImageView(
            url: viewModel.photo.imageURLs.regular,
            pipeline: imagePipeline,
            contentMode: heroContentMode
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

    private var heroMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = viewModel.photo.description {
                Text(description)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Text("Photo by \(viewModel.photo.user.name)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            photographer
            statistics
            userPhotos
        }
        .padding(.top, 20)
        .padding(.bottom, 32)
        .background(.background)
    }

    private var photographer: some View {
        HStack(spacing: 14) {
            RemoteImageView(url: viewModel.photo.user.avatarURL, pipeline: imagePipeline) {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.photo.user.name)
                    .font(.headline)
                    .lineLimit(2)

                Text("@\(viewModel.photo.user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2.bold())

            if let statistics = viewModel.statistics {
                HStack(spacing: 12) {
                    metric(title: "Views", systemImage: "eye", metric: statistics.views)

                    if let likes = statistics.likes {
                        metric(title: "Likes", systemImage: "heart", metric: likes)
                    }

                    metric(title: "Downloads", systemImage: "arrow.down", metric: statistics.downloads)
                }
            } else if viewModel.isLoadingStatistics {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if viewModel.statisticsErrorMessage != nil {
                statisticsFailure
            }
        }
        .padding(.horizontal, 20)
    }

    private func metric(title: String, systemImage: String, metric: PhotoStatistics.Metric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(metric.total.formatted())
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(signed(metric.change)) / \(metric.periodDays)d")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statisticsFailure: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Statistics unavailable")
                    .font(.subheadline.weight(.semibold))

                Text("We couldn't load statistics for this photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await viewModel.retryStatistics()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var additionalUserPhotos: [Photo] {
        viewModel.userPhotos.filter { $0.id != viewModel.photo.id }
    }

    @ViewBuilder
    private var userPhotos: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("More by \(viewModel.photo.user.name)")
                .font(.title2.bold())
                .lineLimit(2)
                .padding(.horizontal, 20)

            if !additionalUserPhotos.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(additionalUserPhotos) { photo in
                            userPhoto(photo)
                        }
                    }
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollIndicators(.hidden)
            } else if viewModel.isLoadingUserPhotos {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if viewModel.userPhotosErrorMessage != nil {
                userPhotosFailure
                    .padding(.horizontal, 20)
            } else {
                Text("No additional photos available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func userPhoto(_ photo: Photo) -> some View {
        Button {
            selectedViewerPhoto = photo
        } label: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
                .frame(width: 160, height: 205)
                .overlay {
                    RemoteImageView(url: photo.imageURLs.small, pipeline: imagePipeline) {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.description ?? "Photo by \(photo.user.name)")
        .accessibilityHint("Opens photo viewer")
    }

    private var userPhotosFailure: some View {
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

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value.formatted())" : value.formatted()
    }
}

#Preview {
    NavigationStack {
        DetailView(
            viewModel: DetailPreviewFixtures.makeViewModel(),
            imagePipeline: TodayPreviewFixtures.imagePipeline
        )
    }
}
