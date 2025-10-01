//
//  RootBottomBarSymbolButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 29/09/2025.
//

import SwiftUI
//
struct RootBottomBarSymbolButton: View {
    let symbol: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("eurusd_icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Text(symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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
}
//
#Preview {
    RootBottomBarSymbolButton(
        symbol: "EUR/USD",
        backgroundColor: AppColors.fadedBackground.opacity(0.1),
        foregroundColor: AppColors.fadedBackground,
        action: { print("Tapped EUR/USD") }
    )
}
