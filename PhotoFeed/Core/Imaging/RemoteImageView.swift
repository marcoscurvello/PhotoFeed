//
//  RemoteImageView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import SwiftUI
import UIKit

struct RemoteImageView<Placeholder: View>: View {

    private enum Phase {
        case loading(url: URL)
        case success(url: URL, image: Image)
        case failure(url: URL)
    }

    private struct PlaceholderRequest: Hashable {
        let url: URL
        let blurHash: String?
    }

    private struct DecodedPlaceholder {
        let blurHash: String
        let image: Image
    }

    private let url: URL
    private let pipeline: RemoteImagePipeline
    private let blurHash: String?
    private let placeholderAspectRatio: CGFloat?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @State private var phase: Phase
    @State private var decodedPlaceholder: DecodedPlaceholder?

    init(
        url: URL,
        pipeline: RemoteImagePipeline,
        blurHash: String? = nil,
        placeholderAspectRatio: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.pipeline = pipeline
        self.blurHash = blurHash
        self.placeholderAspectRatio = placeholderAspectRatio
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
            .task(id: PlaceholderRequest(url: url, blurHash: blurHash)) {
                await loadPlaceholder()
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
                    loadingContent
            }
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        if let blurHash,
           let decodedPlaceholder,
           decodedPlaceholder.blurHash == blurHash {
            placeholderImageContent(decodedPlaceholder.image)
        } else if let blurHash, let cachedPlaceholder = pipeline.cachedPlaceholder(for: blurHash) {
            placeholderImageContent(Image(uiImage: cachedPlaceholder))
        } else {
            placeholder
        }
    }

    private func imageContent(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private func placeholderImageContent(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(placeholderAspectRatio, contentMode: contentMode)
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

    private func loadPlaceholder() async {
        guard let blurHash,
              pipeline.cachedImage(for: url) == nil,
              let image = await pipeline.placeholder(for: blurHash),
              !Task.isCancelled,
              pipeline.cachedImage(for: url) == nil else {
            return
        }

        decodedPlaceholder = DecodedPlaceholder(
            blurHash: blurHash,
            image: Image(uiImage: image)
        )
    }
}

#Preview("Loading") {
    RemoteImageView(
        url: RemoteImagePreviewURLProtocol.loadingURL,
        pipeline: RemoteImagePreviewURLProtocol.makePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

#Preview("BlurHash loading") {
    RemoteImageView(
        url: RemoteImagePreviewURLProtocol.loadingURL,
        pipeline: RemoteImagePreviewURLProtocol.makePipeline(),
        blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
        placeholderAspectRatio: 4 / 3,
        contentMode: .fit
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 200)
    .background(.quaternary)
}

#Preview("Failure") {
    RemoteImageView(
        url: RemoteImagePreviewURLProtocol.failureURL,
        pipeline: RemoteImagePreviewURLProtocol.makePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

#Preview("Network success") {
    RemoteImageView(
        url: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=800")!,
        pipeline: RemoteImagePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

#if DEBUG
private struct RemoteImagePreviewPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                ProgressView()
            }
    }
}

private final class RemoteImagePreviewURLProtocol: URLProtocol, @unchecked Sendable {
    static let loadingURL = URL(string: "preview-image://fixture/loading")!
    static let failureURL = URL(string: "preview-image://fixture/failure")!

    static func makePipeline() -> RemoteImagePipeline {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteImagePreviewURLProtocol.self]
        return RemoteImagePipeline(session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "preview-image"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch request.url?.path {
            case "/loading":
                break

            case "/failure":
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))

            default:
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        }
    }

    override func stopLoading() {}
}
#endif
