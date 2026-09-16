//
//  FixtureSponsoredPhotoSequence.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Foundation

actor FixtureSponsoredPhotoSequence {

    private var nextSequenceNumber = 0

    func next(from templates: [Photo], count: Int) -> [Photo] {
        guard count > 0, !templates.isEmpty else {
            return []
        }

        let sequenceNumbers = nextSequenceNumber..<(nextSequenceNumber + count)
        nextSequenceNumber += count

        return sequenceNumbers.map { sequenceNumber in
            let template = templates[sequenceNumber % templates.count]

            return Photo(
                id: .init(rawValue: "fixture-sponsored-\(sequenceNumber)-\(template.id.rawValue)"),
                width: template.width,
                height: template.height,
                colorHex: template.colorHex,
                description: template.description,
                imageURLs: template.imageURLs,
                user: template.user,
                webpageURL: template.webpageURL
            )
        }
    }
}
