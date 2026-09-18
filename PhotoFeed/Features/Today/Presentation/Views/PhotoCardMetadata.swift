//
//  PhotoCardMetadata.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct PhotoCardMetadata: View {

    let description: String?
    let photographerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description {
                Text(description)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Photo by \(photographerName)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        Color.black

        PhotoCardMetadata(
            description: "A young woman with dark hair illuminated by blue light",
            photographerName: "Ihon karwan"
        )
        .padding(20)
    }
}
