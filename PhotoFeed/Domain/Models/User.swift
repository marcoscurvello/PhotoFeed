//
//  User.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated struct User: Identifiable, Hashable, Sendable {

    nonisolated struct ID: RawRepresentable, Hashable, Sendable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    let id: ID
    let username: String
    let name: String
    let avatarURL: URL
    let webpageURL: URL
}
