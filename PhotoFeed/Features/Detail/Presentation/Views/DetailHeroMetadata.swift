//
//  DetailHeroMetadata.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 15/09/2026.
//

import SwiftUI

struct DetailHeroMetadata: View {

    let description: String?
    let photographerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description {
                Text(description)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Text("Photo by \(photographerName)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    DetailHeroMetadata(
        description: TodayPreviewFixtures.photo.description,
        photographerName: TodayPreviewFixtures.photo.user.name
    )
    .padding(.top, 220)
    .background(.black)
}
