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
}
