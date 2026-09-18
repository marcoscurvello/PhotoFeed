//
//  DetailResourceState.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

nonisolated enum DetailResourceState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(ResourceLoadFailure)
    case retrying(ResourceLoadFailure)

    var loadedValue: Value? {
        guard case .loaded(let value) = self else {
            return nil
        }

        return value
    }

    var sharedRetryFailure: ResourceLoadFailure? {
        let failure: ResourceLoadFailure

        switch self {
        case .failed(let value), .retrying(let value):
            failure = value
        case .idle, .loading, .loaded:
            return nil
        }

        if case .rateLimited = failure {
            return failure
        }

        guard case .after = failure.retryEligibility else {
            return nil
        }

        return failure
    }

    var isRetryingSharedFailure: Bool {
        guard case .retrying = self else {
            return false
        }

        return sharedRetryFailure != nil
    }
}
