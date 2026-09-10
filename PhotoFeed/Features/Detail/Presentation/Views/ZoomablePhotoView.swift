//
//  ZoomablePhotoView.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 10/09/2026.
//

import SwiftUI

struct ZoomablePhotoView: View {

    private enum Constants {
        static let minimumScale: CGFloat = 1
        static let doubleTapScale: CGFloat = 2
        static let maximumScale: CGFloat = 4
    }

    let photo: Photo
    let imagePipeline: RemoteImagePipeline
    let isSelected: Bool

    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = Constants.minimumScale
    @State private var lastScale: CGFloat = Constants.minimumScale
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            RemoteImageView(
                url: photo.imageURLs.regular,
                pipeline: imagePipeline,
                contentMode: .fit
            ) {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(magnifyGesture(containerSize: proxy.size))
            .simultaneousGesture(
                dragGesture(containerSize: proxy.size),
                including: scale > Constants.minimumScale ? .all : .none
            )
            .onTapGesture(count: 2) {
                toggleZoom()
            }
            .onChange(of: isSelected) { _, isSelected in
                guard !isSelected else {
                    return
                }

                resetZoom()
            }
        }
        .clipped()
    }

    private func magnifyGesture(containerSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = clampedScale(lastScale * value.magnification)
                isZoomed = scale > Constants.minimumScale
            }
            .onEnded { value in
                scale = clampedScale(lastScale * value.magnification)

                if scale == Constants.minimumScale {
                    resetZoom()
                } else {
                    offset = clampedOffset(
                        offset,
                        scale: scale,
                        containerSize: containerSize
                    )

                    lastScale = scale
                    lastOffset = offset
                    isZoomed = true
                }
            }
    }

    private func dragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > Constants.minimumScale else {
                    return
                }

                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > Constants.minimumScale else {
                    return
                }

                withAnimation(.snappy) {
                    offset = clampedOffset(
                        offset,
                        scale: scale,
                        containerSize: containerSize
                    )
                }

                lastOffset = offset
            }
    }

    private func toggleZoom() {
        if scale > Constants.minimumScale {
            withAnimation(.snappy) {
                resetZoom()
            }
        } else {
            withAnimation(.snappy) {
                scale = Constants.doubleTapScale
                lastScale = Constants.doubleTapScale
                isZoomed = true
            }
        }
    }

    private func resetZoom() {
        scale = Constants.minimumScale
        lastScale = Constants.minimumScale
        offset = .zero
        lastOffset = .zero
        isZoomed = false
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(
            max(scale, Constants.minimumScale),
            Constants.maximumScale
        )
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat, containerSize: CGSize) -> CGSize {
        let horizontalLimit = containerSize.width * (scale - 1) / 2
        let verticalLimit = containerSize.height * (scale - 1) / 2

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }
}
