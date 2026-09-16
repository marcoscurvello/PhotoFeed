//
//  BlurHashDecoderTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 16/09/2026.
//

import Testing
import UIKit
@testable import PhotoFeed

@Suite("BlurHash decoder")
struct BlurHashDecoderTests {

    @Test("Decodes the documented DC-only solid red vector")
    func decodesSolidRedVector() throws {
        let image = try #require(BlurHashDecoder.decode("00TI:j", width: 1, height: 1))
        let pixel = try #require(image.rgbaPixel(atX: 0, y: 0))

        #expect(pixel.red == 255)
        #expect(pixel.green == 0)
        #expect(pixel.blue == 0)
        #expect(pixel.alpha == 255)
    }

    @Test("Decodes to the requested dimensions")
    func decodesRequestedDimensions() throws {
        let image = try #require(BlurHashDecoder.decode("LEHV6nWB2yk8pyo0adR*.7kCMdnj", width: 32, height: 32))

        #expect(image.cgImage?.width == 32)
        #expect(image.cgImage?.height == 32)
    }

    @Test("Reconstructs the documented multi-component vector")
    func reconstructsMultiComponentVector() throws {
        // Expected pixels come from the canonical BlurHash reference decoder.
        let image = try #require(
            BlurHashDecoder.decode("LEHV6nWB2yk8pyo0adR*.7kCMdnj", width: 4, height: 3)
        )
        let topLeft = try #require(image.rgbaPixel(atX: 0, y: 0))
        let topRight = try #require(image.rgbaPixel(atX: 3, y: 0))
        let center = try #require(image.rgbaPixel(atX: 1, y: 1))
        let bottomCenter = try #require(image.rgbaPixel(atX: 2, y: 2))
        let bottomRight = try #require(image.rgbaPixel(atX: 3, y: 2))

        #expect(topLeft == (135, 164, 177, 255))
        #expect(topRight == (160, 172, 174, 255))
        #expect(center == (148, 148, 154, 255))
        #expect(bottomCenter == (163, 130, 104, 255))
        #expect(bottomRight == (148, 140, 134, 255))
    }

    @Test(arguments: [
        "",
        "00000",
        "00TI:j!",
        "00TI:/",
        "00TSUB",
        "100000~r",
        "LEHV6nWB2yk8pyo0adR*.7kCMdnj!"
    ])
    func rejectsMalformedHashes(_ blurHash: String) {
        #expect(BlurHashDecoder.decode(blurHash) == nil)
    }

    @Test(arguments: [(0, 32), (32, 0), (-1, 32), (32, -1)])
    func rejectsInvalidDimensions(_ dimensions: (Int, Int)) {
        #expect(BlurHashDecoder.decode("00TI:j", width: dimensions.0, height: dimensions.1) == nil)
    }
}

private extension UIImage {
    func rgbaPixel(atX x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard let cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data),
              x >= 0, x < cgImage.width,
              y >= 0, y < cgImage.height else {
            return nil
        }

        let offset = (y * cgImage.bytesPerRow) + (x * 4)
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}
