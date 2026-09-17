//
//  HTTPQueryParameter.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 17/09/2026.
//

import Foundation

nonisolated struct HTTPQueryParameter: Equatable, Sendable {

    let name: String
    let value: String

    init<Name: RawRepresentable>(name: Name, value: String) where Name.RawValue == String {
        self.name = name.rawValue
        self.value = value
    }

    var urlQueryItem: URLQueryItem {
        URLQueryItem(name: name, value: value)
    }
}
