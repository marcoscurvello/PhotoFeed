//
//  HTTPDateParser.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 18/09/2026.
//

import Foundation

nonisolated enum HTTPDateParser {

    private enum Constants {
        static let localeIdentifier = "en_US_POSIX"
        static let dateFormats: [String] = [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy"
        ]
    }

    static func date(from value: String) -> Date? {
        for format in Constants.dateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: Constants.localeIdentifier)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.isLenient = false
            formatter.dateFormat = format

            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
