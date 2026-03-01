//
//  RootBottomBarSymbolButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 29/09/2025.
//  Updated: Added TradingSymbolDTO support for dynamic icons
//

import SwiftUI

struct RootBottomBarSymbolButton: View {
    let symbol: String
    let symbolDTO: RLTradingSymbolDTO?
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    // Backwards-compatible init without DTO
    init(
        symbol: String,
        backgroundColor: Color,
        foregroundColor: Color,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.symbolDTO = nil
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    // New init with DTO for icon/color support
    init(
        symbol: String,
        symbolDTO: RLTradingSymbolDTO?,
        backgroundColor: Color,
        foregroundColor: Color,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.symbolDTO = symbolDTO
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Symbol icon - use DTO if available, otherwise fallback
                symbolIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    if let symbolDTO {
                        Text(symbolDTO.assetClassDisplayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(foregroundColor.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(backgroundColor)
            .clipShape(Capsule())
            .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var symbolIcon: some View {
        if let dto = symbolDTO {
            TradingSymbolIconView(
                symbol: dto,
                size: 40,
                cornerRadiusRatio: 0.5,
                strokeOpacity: 0.3,
                showShadow: false
            )
        } else {
            // No DTO - fallback to default
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(String(symbol.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Without DTO (backwards compatible)
            RootBottomBarSymbolButton(
                symbol: "EUR/USD",
                backgroundColor: AppColors.gradientBackgroundDark,
                foregroundColor: .white,
                action: { print("Tapped EUR/USD") }
            )
            
            // With DTO (example - would need real RLTradingSymbolDTO)
            RootBottomBarSymbolButton(
                symbol: "BTCUSD",
                symbolDTO: nil,
                backgroundColor: AppColors.gradientBackgroundDark,
                foregroundColor: .white,
                action: { print("Tapped BTC") }
            )
        }
    }
}


////
////  RootBottomBarSymbolButton.swift
////  traders_guild
////
////  Created by Al Hennessey on 29/09/2025.
////
//
//import SwiftUI
////
//struct RootBottomBarSymbolButton: View {
//    let symbol: String
//    let backgroundColor: Color
//    let foregroundColor: Color
//    let action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 10) {
//                Image("eurusd_icon")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 40, height: 40)
//                    .clipShape(Circle())
//                    .background(
//                        Circle()
//                            .fill(Color.white)
//                            .frame(width: 44, height: 44)
//                    )
//                    .overlay(
//                        Circle()
//                            .stroke(Color.white, lineWidth: 2)
//                    )
//                
//                Text(symbol)
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundColor(foregroundColor)
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.5)
//                    .padding(.trailing, 4)
//            }
//            .padding(.vertical, 5)
//            .padding(.leading, 5)
//            .padding(.trailing, 12)
//            .frame(height: 50)
//            .background(backgroundColor)
//            .clipShape(Capsule())
//            .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
//        }
//        .padding(.horizontal, 4)
//    }
//}
////
//#Preview {
//    RootBottomBarSymbolButton(
//        symbol: "EUR/USD",
//        backgroundColor: AppColors.fadedBackground.opacity(0.1),
//        foregroundColor: AppColors.fadedBackground,
//        action: { print("Tapped EUR/USD") }
//    )
//}
