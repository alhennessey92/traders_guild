//
//  PlatformColorMath.swift
//  traders_guild
//
//  Cross-platform RGB component, luminance, contrast, and blending maths.
//  The formulae intentionally mirror the shipped UIColor implementation.
//

import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PlatformRGBA: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let zero = PlatformRGBA(red: 0, green: 0, blue: 0, alpha: 0)
}

enum PlatformColorMath {

    static func cgColor(from color: Color) -> CGColor {
        #if canImport(UIKit)
        return UIColor(color).cgColor
        #elseif canImport(AppKit)
        return NSColor(color).cgColor
        #else
        return color.cgColor ?? CGColor(gray: 0, alpha: 0)
        #endif
    }

    static func rgba(of color: CGColor) -> PlatformRGBA? {
        guard let components = color.components else { return nil }

        switch color.colorSpace?.model {
        case .monochrome:
            guard let white = components.first else { return nil }
            return PlatformRGBA(red: white, green: white, blue: white, alpha: color.alpha)
        case .rgb:
            guard components.count >= 3 else { return nil }
            return PlatformRGBA(
                red: components[0],
                green: components[1],
                blue: components[2],
                alpha: color.alpha
            )
        default:
            return nil
        }
    }

    static func contrastRatio(between first: CGColor, and second: CGColor) -> CGFloat {
        let firstLuminance = relativeLuminance(of: first)
        let secondLuminance = relativeLuminance(of: second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func blended(_ first: CGColor, with second: CGColor, amount: CGFloat) -> CGColor {
        let clampedAmount = min(1.0, max(0.0, amount))
        let firstComponents = rgba(of: first) ?? .zero
        let secondComponents = rgba(of: second) ?? .zero
        let components = [
            firstComponents.red + (secondComponents.red - firstComponents.red) * clampedAmount,
            firstComponents.green + (secondComponents.green - firstComponents.green) * clampedAmount,
            firstComponents.blue + (secondComponents.blue - firstComponents.blue) * clampedAmount,
            firstComponents.alpha + (secondComponents.alpha - firstComponents.alpha) * clampedAmount,
        ]
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        return CGColor(colorSpace: colorSpace, components: components)!
    }

    static func adjustedForeground(
        _ foreground: CGColor,
        against background: CGColor,
        minimumContrast: CGFloat
    ) -> CGColor {
        let contrast = contrastRatio(between: foreground, and: background)
        guard contrast < minimumContrast else { return foreground }

        let deficit = minimumContrast - contrast
        let blendAmount = min(0.6, max(0.2, deficit / minimumContrast))
        return blended(foreground, with: CGColor(gray: 1, alpha: 1), amount: blendAmount)
    }

    private static func relativeLuminance(of color: CGColor) -> CGFloat {
        let components = rgba(of: color) ?? .zero

        func channel(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        let red = channel(components.red)
        let green = channel(components.green)
        let blue = channel(components.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
