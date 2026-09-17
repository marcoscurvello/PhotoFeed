//
//  ResourceLoadFailurePresentation.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import SwiftUI

struct ResourceLoadFailurePresentation {

    enum Context {
        case feed
        case statistics
        case userPhotos
    }

    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    init(_ failure: ResourceLoadFailure, context: Context = .feed) {
        switch failure {
        case .offline:
            title = "You’re offline"
            message = "Check your internet connection and try again."
            systemImage = "wifi.exclamationmark"
        case .timedOut:
            title = "The request timed out"
            message = "The photo service took too long to respond."
            systemImage = "clock.badge.exclamationmark"
        case .rateLimited(let snapshot):
            title = "Photo requests are temporarily limited"
            if let limit = snapshot.limit {
                message = "The hourly photo request limit of \(limit) has been reached."
            } else {
                message = snapshot.retryAfter == nil
                    ? "The hourly photo request limit has been reached. Please try again later."
                    : "The hourly photo request limit has been reached."
            }
            systemImage = "hourglass"
        case .serviceUnavailable:
            title = "Photo service unavailable"
            message = "Unsplash is temporarily unavailable."
            systemImage = "exclamationmark.icloud"
        case .accessDenied:
            title = "Photo service unavailable"
            message = "Photos can’t be loaded with the current service access."
            systemImage = "lock.trianglebadge.exclamationmark"
        case .notFound:
            title = "Photos unavailable"
            switch context {
            case .feed:
                message = "The requested photos are no longer available."
            case .statistics:
                message = "Statistics are no longer available for this photo."
            case .userPhotos:
                message = "More photos by this photographer are no longer available."
            }
            systemImage = "photo.badge.exclamationmark"
        case .invalidResponse:
            title = "Photos unavailable"
            message = "The photo service returned an unexpected response."
            systemImage = "exclamationmark.triangle"
        case .unknown:
            title = "Unable to load photos"
            message = "Please try again."
            systemImage = "exclamationmark.triangle"
        }
    }
}
