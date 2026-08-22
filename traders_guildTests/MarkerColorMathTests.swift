import CoreGraphics
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import traders_guild

enum MarkerColorMathRegression {

    #if canImport(UIKit)
    static func assertShippedOutputsArePinned() {
        let background = UIColor(
            red: 25.0 / 255.0,
            green: 25.0 / 255.0,
            blue: 33.0 / 255.0,
            alpha: 1
        )
        let fixtures: [(name: String, marker: UIColor, expected: [CGFloat])] = [
            (
                "black",
                UIColor(red: 0, green: 0, blue: 0, alpha: 1),
                [0.57058999877820726, 0.57058999877820726, 0.57058999877820726, 1]
            ),
            (
                "white",
                UIColor(red: 1, green: 1, blue: 1, alpha: 1),
                [1, 1, 1, 1]
            ),
            (
                "bear",
                UIColor(red: 0.7, green: 0.1, blue: 0.12, alpha: 0.8),
                [0.76, 0.28, 0.296, 0.84]
            ),
            (
                "bull",
                UIColor(red: 0.1, green: 0.65, blue: 0.35, alpha: 1),
                [0.1, 0.65, 0.35, 1]
            ),
            (
                "blue",
                UIColor(red: 0.05, green: 0.25, blue: 0.8, alpha: 0.35),
                [0.26169041226355788, 0.41712400968175622, 0.84456640258180171, 0.49484080839085537]
            ),
            (
                "grey",
                UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),
                [0.45, 0.45, 0.45, 1]
            ),
        ]

        for fixture in fixtures {
            let shippedOutput = shippedMarkerLabelColor(fixture.marker, against: background)
            let shippedComponents = rgba(shippedOutput)
            let shipped = [
                shippedComponents.red,
                shippedComponents.green,
                shippedComponents.blue,
                shippedComponents.alpha,
            ]

            let cgOutput = PlatformColorMath.adjustedForeground(
                fixture.marker.cgColor,
                against: background.cgColor,
                minimumContrast: 2.8
            )
            let cgComponents = PlatformColorMath.rgba(of: cgOutput)!
            let crossPlatform = [
                cgComponents.red,
                cgComponents.green,
                cgComponents.blue,
                cgComponents.alpha,
            ]

            for (component, expected) in zip(shipped, fixture.expected) {
                #expect(
                    abs(component - expected) < 0.000_000_000_001,
                    "\(fixture.name) shipped output changed: expected \(fixture.expected), got \(shipped)"
                )
            }
            for (component, expected) in zip(crossPlatform, fixture.expected) {
                #expect(
                    abs(component - expected) < 0.000_000_000_001,
                    "\(fixture.name) CGColor output differs: expected \(fixture.expected), got \(crossPlatform)"
                )
            }
        }
    }

    private static func shippedMarkerLabelColor(_ markerColor: UIColor, against background: UIColor) -> UIColor {
        let minimumContrast: CGFloat = 2.8
        let contrast = shippedContrastRatio(markerColor, against: background)
        if contrast >= minimumContrast {
            return markerColor
        }

        let deficit = minimumContrast - contrast
        let blendAmount = min(0.6, max(0.2, deficit / minimumContrast))
        return shippedBlend(markerColor, with: .white, amount: blendAmount)
    }

    private static func shippedContrastRatio(_ first: UIColor, against second: UIColor) -> CGFloat {
        let firstLuminance = shippedRelativeLuminance(first)
        let secondLuminance = shippedRelativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func shippedRelativeLuminance(_ color: UIColor) -> CGFloat {
        let components = rgba(color)

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

    private static func shippedBlend(_ first: UIColor, with second: UIColor, amount: CGFloat) -> UIColor {
        let clampedAmount = min(1.0, max(0.0, amount))
        let firstComponents = rgba(first)
        let secondComponents = rgba(second)
        return UIColor(
            red: firstComponents.red + (secondComponents.red - firstComponents.red) * clampedAmount,
            green: firstComponents.green + (secondComponents.green - firstComponents.green) * clampedAmount,
            blue: firstComponents.blue + (secondComponents.blue - firstComponents.blue) * clampedAmount,
            alpha: firstComponents.alpha + (secondComponents.alpha - firstComponents.alpha) * clampedAmount
        )
    }

    private static func rgba(_ color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return (red, green, blue, alpha)
    }
    #endif
}
