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

    private enum ImagePhase {
        case loading
        case success(Image)
        case failure
    }

    private struct ImageState {
        let url: URL
        var phase: ImagePhase
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

    @State private var imageState: ImageState
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
        _imageState = State(initialValue: ImageState(url: url, phase: .loading))
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
        if imageState.url == url,
           case .success(let image) = imageState.phase {
            imageContent(image)
        } else if let cachedImage = pipeline.cachedImage(for: url) {
            imageContent(Image(uiImage: cachedImage))
        } else if imageState.url == url,
                  case .failure = imageState.phase {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding()
        } else {
            loadingContent
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
        let requestURL = url

        guard beginImageRequest(for: requestURL) else {
            return
        }

        if let cachedImage = pipeline.cachedImage(for: requestURL) {
            transition(to: .success(Image(uiImage: cachedImage)), for: requestURL)
            return
        }

        do {
            let image = try await pipeline.image(for: requestURL)
            transition(to: .success(Image(uiImage: image)), for: requestURL)
        } catch {
            transition(to: .failure, for: requestURL)
        }
    }

    private func beginImageRequest(for requestURL: URL) -> Bool {
        guard !Task.isCancelled else {
            return false
        }

        if imageState.url != requestURL {
            imageState = ImageState(url: requestURL, phase: .loading)
            return true
        }

        if case .success = imageState.phase {
            return false
        }

        imageState.phase = .loading
        return true
    }

    private func transition(to phase: ImagePhase, for requestURL: URL) {
        guard !Task.isCancelled, imageState.url == requestURL else {
            return
        }

        imageState.phase = phase
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
