//
//  RemoteImageView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation
import SwiftUI
import UIKit

struct RemoteImageView<Fallback: View>: View {

    private enum Phase {
        case empty
        case loading(RemoteImageRequest, preview: UIImage?)
        case success(RemoteImageRequest, image: UIImage)
        case failure(RemoteImageRequest)
    }

    private let request: RemoteImageRequest
    private let pipeline: RemoteImagePipeline

    private let previewAspectRatio: CGFloat?

    private let contentMode: ContentMode
    private let fallback: Fallback

    @State private var phase: Phase = .empty

    init(
        request: RemoteImageRequest,
        pipeline: RemoteImagePipeline,
        previewAspectRatio: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.request = request
        self.pipeline = pipeline
        self.previewAspectRatio = previewAspectRatio
        self.contentMode = contentMode
        self.fallback = fallback()
    }

    var body: some View {
        content
            .task(id: request) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if case .success(let stateRequest, let image) = phase, stateRequest == request {
            imageContent(image)

        } else if case .failure(let stateRequest) = phase, stateRequest == request {
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
        if case .loading(let stateRequest, let preview) = phase,
           stateRequest == request,
           let preview {
            previewImageContent(preview)
        } else {
            switch pipeline.cachedContent(for: request) {
                case .image(let image):
                    imageContent(image)

                case .preview(let image):
                    previewImageContent(image)

                case nil:
                    fallback
            }
        }
    }

    private func imageContent(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private func previewImageContent(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(previewAspectRatio, contentMode: contentMode)
    }

    private func load() async {
        guard !Task.isCancelled else {
            return
        }

        phase = .loading(request, preview: nil)

        do {
            for try await update in await pipeline.updates(for: request) {
                guard !Task.isCancelled else {
                    return
                }

                switch update {
                    case .preview(let image):
                        phase = .loading(request, preview: image)

                    case .image(let image):
                        phase = .success(request, image: image)
                }
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            phase = .failure(request)
        }
    }
}

extension RemoteImageView where Fallback == Color {
    init(
        request: RemoteImageRequest,
        pipeline: RemoteImagePipeline,
        previewAspectRatio: CGFloat? = nil,
        contentMode: ContentMode = .fill
    ) {
        self.init(
            request: request,
            pipeline: pipeline,
            previewAspectRatio: previewAspectRatio,
            contentMode: contentMode
        ) {
            Color.clear
        }
    }
}

#if DEBUG
#Preview("Loading") {
    RemoteImageView(
        request: RemoteImageRequest(url: RemoteImagePreviewURLProtocol.loadingURL),
        pipeline: RemoteImagePreviewURLProtocol.makePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

#Preview("BlurHash loading") {
    RemoteImageView(
        request: RemoteImageRequest(
            url: RemoteImagePreviewURLProtocol.loadingURL,
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        ),
        pipeline: RemoteImagePreviewURLProtocol.makePipeline(),
        previewAspectRatio: 4 / 3,
        contentMode: .fit
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 200)
    .background(.quaternary)
}

#Preview("Failure") {
    RemoteImageView(
        request: RemoteImageRequest(url: RemoteImagePreviewURLProtocol.failureURL),
        pipeline: RemoteImagePreviewURLProtocol.makePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

#Preview("Network success") {
    RemoteImageView(
        request: RemoteImageRequest(
            url: URL(string: "https://images.unsplash.com/photo-1417325384643-aac51acc9e5d?w=800")!
        ),
        pipeline: RemoteImagePipeline()
    ) {
        RemoteImagePreviewPlaceholder()
    }
    .frame(width: 300, height: 400)
    .clipped()
}

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
            case "/loading": break
            case "/failure": client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            default: client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        }
    }

    override func stopLoading() {}
}
#endif
