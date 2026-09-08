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
        case loading
        case success(Image)
        case failure
    }

    private let url: URL
    private let pipeline: RemoteImagePipeline
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder

    @State private var phase: Phase = .loading

    init(
        url: URL,
        pipeline: RemoteImagePipeline,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.pipeline = pipeline
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        content
            .task(id: url) {
                await loadImage()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            placeholder()

        case .success(let image):
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)

        case .failure:
            placeholder()
        }
    }

    private func loadImage() async {
        phase = .loading

        do {
            let data = try await pipeline.data(for: url)

            guard !Task.isCancelled else {
                return
            }

            guard let image = UIImage(data: data) else {
                phase = .failure
                return
            }
            
            phase = .success(Image(uiImage: image))
        } catch {
            guard !Task.isCancelled else {
                return
            }

            phase = .failure
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
