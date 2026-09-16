//
//  RemoteImageView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import SwiftUI
import UIKit

struct RemoteImageView<Placeholder: View>: View {

    private enum Phase {
        case loading(url: URL)
        case success(url: URL, image: Image)
        case failure(url: URL)
    }

    private let url: URL
    private let pipeline: RemoteImagePipeline
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @State private var phase: Phase

    init(
        url: URL,
        pipeline: RemoteImagePipeline,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.pipeline = pipeline
        self.contentMode = contentMode
        self.placeholder = placeholder()
        _phase = State(
            initialValue: pipeline.cachedImage(for: url).map {
                .success(url: url, image: Image(uiImage: $0))
            } ?? .loading(url: url)
        )
    }

    var body: some View {
        content
            .task(id: url) {
                await loadImage()
            }
    }

    @ViewBuilder
    private var content: some View {
        if case .success(let imageURL, let image) = phase, imageURL == url {
            imageContent(image)
        } else if let cachedImage = pipeline.cachedImage(for: url) {
            imageContent(Image(uiImage: cachedImage))
        } else {
            switch phase {
                case .failure(let failedURL) where failedURL == url:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding()

                default:
                    placeholder
            }
        }
    }

    private func imageContent(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private func loadImage() async {
        if case .success(let successfulURL, _) = phase, successfulURL == url {
            return
        }

        if let cachedImage = pipeline.cachedImage(for: url) {
            phase = .success(url: url, image: Image(uiImage: cachedImage))
            return
        }

        phase = .loading(url: url)

        do {
            let image = try await pipeline.image(for: url)

            guard !Task.isCancelled else {
                return
            }

            phase = .success(url: url, image: Image(uiImage: image))
        } catch {
            guard !Task.isCancelled else {
                return
            }

            phase = .failure(url: url)
        }
    }
}

#Preview {
    RemoteImageView(
        url: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=800")!,
        pipeline: RemoteImagePipeline()
    ) {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                ProgressView()
            }
    }
    .frame(width: 300, height: 400)
    .clipped()
}
