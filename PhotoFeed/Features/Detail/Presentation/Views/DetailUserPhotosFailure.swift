//
//  DetailUserPhotosFailure.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct DetailUserPhotosFailure: View {

    let viewModel: DetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("More photos couldn't be loaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button("Retry") {
                Task {
                    await viewModel.retryUserPhotos()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
#Preview {
    @Previewable @State var viewModel = DetailPreviewFixtures.makeViewModel(userPhotosBehavior: .failure)

    DetailUserPhotosFailure(viewModel: viewModel)
}
