//
//  DetailPhotographer.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailPhotographer: View {

    let user: User
    let imagePipeline: RemoteImagePipeline

    var body: some View {
        HStack(spacing: 14) {
            RemoteImageView(url: user.avatarURL, pipeline: imagePipeline) {
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
                Text(user.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(verbatim: "@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DetailPhotographer(
        user: TodayPreviewFixtures.photo.user,
        imagePipeline: TodayPreviewFixtures.imagePipeline
    )
}
