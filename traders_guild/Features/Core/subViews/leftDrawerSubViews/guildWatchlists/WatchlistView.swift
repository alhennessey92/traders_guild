//
//  WatchlistView.swift
//  traders_guild
//
//  Created by Al Hennessey on 10/10/2025.
//

import SwiftUI



// MARK: - Announcements List View
struct WatchlistView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.watchlist == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Guild Watchlist...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            else if leftDrawerViewModel.watchlist?.symbols.isEmpty ?? true {
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
                // ✅ Unwrap the single watchlist, then loop through its symbols
                if let symbols = leftDrawerViewModel.watchlist?.symbols {
                    ForEach(symbols) { symbol in
                        WatchlistRowView(
                            symbol: symbol,
                            onTap: {
                                print("Tapped on \(symbol.ticker)")
                            }
                        )
                    }
                } else {
                    // ✅ Show empty state if no watchlist
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No symbols yet")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}



// MARK: - Watchlist Row View
struct WatchlistRowView: View {
    let symbol: SymbolDTO
    let onTap: () -> Void

    
    @State private var isPressed = false
    
    // Computed properties to simplify the complex expressions
    private var isMarketOpen: Bool {
        symbol.symbolStatus == .open
    }
    
    private var statusIcon: String {
        isMarketOpen ? "circle.circle.fill" : "moon.fill"
    }
    
    private var statusColor: Color {
        isMarketOpen ? AppColors.bullCandleGreen : AppColors.accentDarkColor
    }
    
    
    private var statusView: some View {
        Group {
            if isMarketOpen {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            } else {
                Image(systemName: statusIcon)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(statusColor, .white)
            }
        }
        .font(.caption2)
        .fontWeight(.regular)
    }
    
    private var isDirectionPositive: Bool{
        symbol.isUp == true
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(String(symbol.ticker.prefix(2)))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(symbol.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        
                        statusView
                    }
                    
                    Text(symbol.symbolType.rawValue)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(symbol.price, format: .currency(code: "USD"))
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(isDirectionPositive ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                    Text("\(symbol.changeFormatted)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isDirectionPositive ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                }
                .padding(.leading, 4)
            }
            .padding(.trailing, 16)
            .padding(.leading, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 56, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1)
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

