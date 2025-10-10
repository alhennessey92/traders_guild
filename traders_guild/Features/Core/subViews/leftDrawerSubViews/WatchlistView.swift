//
//  WatchlistView.swift
//  traders_guild
//
//  Created by Al Hennessey on 10/10/2025.
//

import SwiftUI



// MARK: - Announcements List View
struct WatchlistView: View {
    let guildWatchlist: GuildWatchlist
    
    var body: some View {
        VStack(spacing: 10) {
            if guildWatchlist.symbols.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No Symbols in Guild Watchlist")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    Text("Check back later for guild updates")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(guildWatchlist.symbolObjects) { symbol in
                    WatchlistRowView(
                        symbol: symbol,
                        onTap: {
                            print("Tapped on \(symbol.ticker)")
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}



// MARK: - Watchlist Row View
struct WatchlistRowView: View {
    let symbol: Symbol
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.accentColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(String(symbol.ticker.prefix(2)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(symbol.symbol)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Technology")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(Int.random(in: 100...500))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    Text("+\(String(format: "%.2f", Double.random(in: 0.5...5.0)))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    
                }
                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 14)
//                        .fill(
//                            Color.white
//                                .opacity(isPressed ? 0.1 : 0.02)
//                        )
//                    
//                )
                .cornerRadius(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        Color.white
                            .opacity(isPressed ? 0.1 : 0.02)
                    )
                    
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
