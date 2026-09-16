//
//  BlurHashDecoder.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

import CoreGraphics
import Foundation
import UIKit

nonisolated enum BlurHashDecoder {

    static let placeholderDimension = 32

    static func decode(
        _ blurHash: String,
        width: Int = placeholderDimension,
        height: Int = placeholderDimension
    ) -> UIImage? {
        guard width > 0, height > 0 else {
            return nil
        }

        let characters = Array(blurHash.utf8)

        guard characters.count >= 6 else {
            return nil
        }

        guard let sizeFlag = decode83(characters[0...0]), sizeFlag < 81 else {
            return nil
        }

        let componentCountX = (sizeFlag % 9) + 1
        let componentCountY = (sizeFlag / 9) + 1
        let expectedLength = 4 + (2 * componentCountX * componentCountY)

        guard
            characters.count == expectedLength,
            let quantizedMaximumValue = decode83(characters[1...1]),
            let decodedDCValue = decode83(characters[2...5]),
            decodedDCValue <= 0xFF_FF_FF
        else {
            return nil
        }

        let maximumValue = Double(quantizedMaximumValue + 1) / 166
        var components = [ColorComponent](repeating: .zero, count: componentCountX * componentCountY)
        components[0] = decodeDC(decodedDCValue)

        for index in 1..<components.count {
            let startIndex = 4 + (index * 2)

            guard let decodedACValue = decode83(characters[startIndex..<(startIndex + 2)]) else {
                return nil
            }

            guard decodedACValue < 19 * 19 * 19 else {
                return nil
            }

            components[index] = decodeAC(decodedACValue, maximumValue: maximumValue)
        }

        let xBasis = cosineBasis(
            outputLength: width,
            componentCount: componentCountX
        )
        let yBasis = cosineBasis(
            outputLength: height,
            componentCount: componentCountY
        )
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            guard !Task.isCancelled else {
                return nil
            }

            for x in 0..<width {
                var color = ColorComponent.zero

                for componentY in 0..<componentCountY {
                    let yWeight = yBasis[y][componentY]

                    for componentX in 0..<componentCountX {
                        let component = components[componentX + (componentY * componentCountX)]
                        color.adding(component, weightedBy: xBasis[x][componentX] * yWeight)
                    }
                }

                let pixelOffset = (y * width + x) * 4
                pixels[pixelOffset] = linearToSRGB(color.red)
                pixels[pixelOffset + 1] = linearToSRGB(color.green)
                pixels[pixelOffset + 2] = linearToSRGB(color.blue)
                pixels[pixelOffset + 3] = .max
            }
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let dataProvider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).union(.byteOrder32Big),
                  provider: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: image)
    }

    private static func cosineBasis(outputLength: Int, componentCount: Int) -> [[Double]] {
        (0..<outputLength).map { outputIndex in
            (0..<componentCount).map { componentIndex in
                cos(Double.pi * Double(outputIndex * componentIndex) / Double(outputLength))
            }
        }
    }

    private static func decode83(_ characters: ArraySlice<UInt8>) -> Int? {
        var value = 0

        for character in characters {
            guard let digit = base83Values[character] else {
                return nil
            }

            value = (value * 83) + digit
        }

        return value
    }

    private static func decodeDC(_ value: Int) -> ColorComponent {
        ColorComponent(
            red: sRGBToLinear(value >> 16),
            green: sRGBToLinear((value >> 8) & 255),
            blue: sRGBToLinear(value & 255)
        )
    }

    private static func decodeAC(_ value: Int, maximumValue: Double) -> ColorComponent {
        let quantizedRed = value / (19 * 19)
        let quantizedGreen = (value / 19) % 19
        let quantizedBlue = value % 19

        return ColorComponent(
            red: signedPower(Double(quantizedRed - 9) / 9, exponent: 2) * maximumValue,
            green: signedPower(Double(quantizedGreen - 9) / 9, exponent: 2) * maximumValue,
            blue: signedPower(Double(quantizedBlue - 9) / 9, exponent: 2) * maximumValue
        )
    }

    private static func sRGBToLinear(_ value: Int) -> Double {
        let normalized = Double(value) / 255
        return normalized <= 0.04045
            ? normalized / 12.92
            : pow((normalized + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ value: Double) -> UInt8 {
        let clamped = min(max(value, 0), 1)
        let normalized = clamped <= 0.0031308
            ? clamped * 12.92
            : (1.055 * pow(clamped, 1 / 2.4)) - 0.055

        return UInt8(min(max(Int((normalized * 255).rounded()), 0), 255))
    }

    private static func signedPower(_ value: Double, exponent: Double) -> Double {
        copysign(pow(abs(value), exponent), value)
    }

    private static let base83Values: [UInt8: Int] = {
        let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
        return Dictionary(uniqueKeysWithValues: alphabet.utf8.enumerated().map { ($0.element, $0.offset) })
    }()

    private struct ColorComponent {
        static let zero = ColorComponent(red: 0, green: 0, blue: 0)

        var red: Double
        var green: Double
        var blue: Double

        mutating func adding(_ other: ColorComponent, weightedBy weight: Double) {
            red += other.red * weight
            green += other.green * weight
            blue += other.blue * weight
        }
    }
}
