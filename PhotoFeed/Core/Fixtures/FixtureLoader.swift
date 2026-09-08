//
//  FixtureLoader.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 08/09/2026.
//

import Foundation

nonisolated enum FixtureLoaderError: Error, Equatable {
    case resourceNotFound(String)
}

nonisolated struct FixtureLoader {

    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    func load<Response: Decodable>(_ type: Response.Type = Response.self, named resourceName: String) throws -> Response {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw FixtureLoaderError.resourceNotFound(resourceName)
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(Response.self, from: data)
    }
}
