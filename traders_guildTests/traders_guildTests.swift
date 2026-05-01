//
//  traders_guildTests.swift
//  traders_guildTests
//
//  Created by Al Hennessey on 16/07/2025.
//

import Testing
import SwiftUI
import UIKit
@testable import traders_guild

struct traders_guildTests {

    @Test func emailIdentifierValidation() async throws {
        #expect(RLAuthValidator.isValidIdentifier("user@example.com"))
        #expect(!RLAuthValidator.isValidIdentifier("invalid@email"))
    }

    @Test func usernameValidation() async throws {
        #expect(RLAuthValidator.isValidUsername("alpha_trader-01"))
        #expect(!RLAuthValidator.isValidUsername("ab"))
        #expect(!RLAuthValidator.isValidUsername("bad username with spaces"))
    }

    @Test func passwordValidation() async throws {
        #expect(RLAuthValidator.isValidPassword("StrongPass1"))
        #expect(!RLAuthValidator.isValidPassword("weak"))
        #expect(!RLAuthValidator.isValidPassword("alllowercase123"))
        #expect(!RLAuthValidator.isValidPassword("ALLUPPERCASE123"))
        #expect(!RLAuthValidator.isValidPassword("NoNumberPassword"))
    }

    @Test func confirmPasswordValidation() async throws {
        #expect(RLAuthValidator.doPasswordsMatch("StrongPass1", "StrongPass1"))
        #expect(!RLAuthValidator.doPasswordsMatch("StrongPass1", "StrongPass2"))
    }

    @Test func appleDisplayNameNormalizationTrimsWhitespace() async throws {
        #expect(RLAuthValidator.normalizedAppleDisplayName("  Jane Appleseed  ") == "Jane Appleseed")
    }

    @Test func appleDisplayNameNormalizationLeavesMissingNamesBlank() async throws {
        #expect(RLAuthValidator.normalizedAppleDisplayName(nil).isEmpty)
        #expect(RLAuthValidator.normalizedAppleDisplayName("   ").isEmpty)
    }

    @Test func sheetDarkAliasResolvesToDarkAssetToken() async throws {
        #expect(colorDistance(AppColors.sheetBackgroundDark, AppColors.tgSheetDarkBackground) < 0.0001)
    }

    @Test func accentAliasResolvesToAccentAssetToken() async throws {
        #expect(colorDistance(AppColors.accentColor, AppColors.tgAccent) < 0.0001)
    }

    @Test func bullAndBearAssetValuesRemainStable() async throws {
        #expect(colorDistance(AppColors.tgBull, Color(red: 0x4A / 255.0, green: 0x94 / 255.0, blue: 0x76 / 255.0)) < 0.0001)
        #expect(colorDistance(AppColors.tgBear, Color(red: 0xA6 / 255.0, green: 0x2C / 255.0, blue: 0x2B / 255.0)) < 0.0001)
    }

    @Test func sharedSurfaceOpacityTokensRemainStable() async throws {
        #expect(colorDistance(AppColors.surfaceWhite08, AppColors.systemWhite.opacity(0.08)) < 0.0001)
        #expect(colorDistance(AppColors.surfaceBlack85, AppColors.systemBlack.opacity(0.85)) < 0.0001)
        #expect(colorDistance(AppColors.surfaceGray30, AppColors.systemGray.opacity(0.3)) < 0.0001)
    }

    @Test func cryptoTickerResolverCoversExpandedBundledIconSet() async throws {
        #expect(BundledTradingSymbolIconResolver.assetName(for: "BTC/USD", assetClass: "crypto") == "icon_btc")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "ETH/USD", assetClass: "crypto") == "icon_eth")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "SOL/USD", assetClass: "crypto") == "icon_sol")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "ADA/USD", assetClass: "crypto") == "icon_ada")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "XRP/USD", assetClass: "crypto") == "icon_xrp")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "DOGE/USD", assetClass: "crypto") == "icon_doge")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "SHIB/USD", assetClass: "crypto") == "icon_shib")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "ATOM/USD", assetClass: "crypto") == "icon_atom")
        #expect(BundledTradingSymbolIconResolver.assetName(for: "LTC/USD", assetClass: "crypto") == "icon_ltc")
    }

    private func colorDistance(_ lhs: Color, _ rhs: Color) -> Double {
        guard let lhsRGBA = rgba(lhs), let rhsRGBA = rgba(rhs) else { return .infinity }
        let dr = lhsRGBA.r - rhsRGBA.r
        let dg = lhsRGBA.g - rhsRGBA.g
        let db = lhsRGBA.b - rhsRGBA.b
        let da = lhsRGBA.a - rhsRGBA.a
        return (dr * dr) + (dg * dg) + (db * db) + (da * da)
    }

    private func rgba(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double)? {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

}
