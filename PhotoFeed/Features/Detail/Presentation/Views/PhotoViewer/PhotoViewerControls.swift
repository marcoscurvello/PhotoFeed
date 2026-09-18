//
//  PhotoViewerControls.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct PhotoViewerControls: View {

    let currentPosition: Int?
    let totalCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")

                Spacer()

                if let currentPosition {
                    Text(
                        "\(currentPosition, format: .number) / \(totalCount, format: .number)",
                        comment: "Position in the photo viewer. The first value is the current photo and the second is the total number of photos."
                    )
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
}

#Preview {
    PhotoViewerControls(currentPosition: 2, totalCount: 5)
        .background(.black)
}
