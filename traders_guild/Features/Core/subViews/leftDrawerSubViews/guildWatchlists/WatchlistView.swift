//
//  WatchlistView.swift
//  traders_guild
//
//  Created by Al Hennessey on 10/10/2025.
//

import SwiftUI

// MARK: - Watchlist View
struct WatchlistView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        ScrollView {
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
                        Image(systemName: "chart.line.uptrend.xyaxis")
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
                    // ✅ Group symbols by type
                    if let symbols = leftDrawerViewModel.watchlist?.symbols {
                        WatchlistGroupedView(symbols: symbols) { symbol in
                            // TODO: Navigate to chart view with symbol
                            print("Navigate to chart for \(symbol.ticker)")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Grouped Watchlist View
struct WatchlistGroupedView: View {
    let symbols: [SymbolDTO]
    let onSymbolTap: (SymbolDTO) -> Void
    
    // Group symbols by type
    private var groupedSymbols: [SymbolDTOType: [SymbolDTO]] {
        Dictionary(grouping: symbols, by: { $0.symbolType })
    }
    
    // Ordered types for consistent display
    private let orderedTypes: [SymbolDTOType] = [.stocks, .cryptocurrency, .forex, .commodities]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(orderedTypes, id: \.self) { symbolType in
                WatchlistDisclosureGroup(
                    symbolType: symbolType,
                    symbols: groupedSymbols[symbolType] ?? [],
                    onSymbolTap: onSymbolTap
                )
            }
        }
    }
}

// MARK: - Disclosure Group for Symbol Type
struct WatchlistDisclosureGroup: View {
    let symbolType: SymbolDTOType
    let symbols: [SymbolDTO]
    let onSymbolTap: (SymbolDTO) -> Void
    
    @State private var isExpanded: Bool = true
    
    private var symbolTypeIcon: String {
        switch symbolType {
        case .stocks:
            return "chart.bar.fill"
        case .cryptocurrency:
            return "bitcoinsign.circle.fill"
        case .forex:
            return "dollarsign.circle.fill"
        case .commodities:
            return "cube.fill"
        }
    }
    
    private var symbolTypeColor: Color {
        switch symbolType {
        case .stocks:
            return AppColors.accentColor
        case .cryptocurrency:
            return .orange
        case .forex:
            return AppColors.bullCandleGreen
        case .commodities:
            return .yellow
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: symbolTypeIcon)
                        .font(.caption)
                        .foregroundColor(symbolTypeColor)
                        .frame(width: 16)
                    
                    // Type name
                    Text(symbolType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    // Count
                    Text("(\(symbols.count))")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Symbols list
            if isExpanded {
                if symbols.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                        Text("No \(symbolType.rawValue.lowercased()) in watchlist")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 6) {
                        ForEach(symbols) { symbol in
                            WatchlistRowView(
                                symbol: symbol,
                                onTap: {
                                    onSymbolTap(symbol)
                                    HapticFeedback.light.trigger()
                                }
                            )
                        }
                    }
                }
            }
        }
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
                        Text(symbol.ticker)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        
                        statusView
                    }
                    
                    Text(symbol.name)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(symbol.price.formatted())
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                    Text("\(symbol.change.formatted())  \(symbol.changeFormatted)")
                        .font(.footnote)
                        .fontWeight(.regular)
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
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.03))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 14)
//                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1)
//                    )
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

//import SwiftUI
//
//
//
//// MARK: - Announcements List View
//struct WatchlistView: View {
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    var body: some View {
//        VStack(spacing: 10) {
//            // ✅ Loading state
//            if leftDrawerViewModel.isLoading && leftDrawerViewModel.watchlist == nil {
//                VStack(spacing: 16) {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                    Text("Loading Guild Watchlist...")
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 40)
//            }
//            else if leftDrawerViewModel.watchlist?.symbols.isEmpty ?? true {
//                VStack(spacing: 12) {
//                    Image(systemName: "megaphone")
//                        .font(.largeTitle)
//                        .foregroundColor(AppColors.whiteText.opacity(0.3))
//                    Text("No Symbols in Guild Watchlist")
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                    Text("Check back later for guild updates")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.4))
//                        .multilineTextAlignment(.center)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 40)
//            } else {
//                // ✅ Unwrap the single watchlist, then loop through its symbols
//                if let symbols = leftDrawerViewModel.watchlist?.symbols {
//                    ForEach(symbols) { symbol in
//                        WatchlistRowView(
//                            symbol: symbol,
//                            onTap: {
//                                print("Tapped on \(symbol.ticker)")
//                            }
//                        )
//                    }
//                } else {
//                    // ✅ Show empty state if no watchlist
//                    VStack(spacing: 12) {
//                        Image(systemName: "chart.line.uptrend.xyaxis")
//                            .font(.largeTitle)
//                            .foregroundColor(.secondary)
//                        Text("No symbols yet")
//                            .foregroundColor(.secondary)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 40)
//                }
//            }
//        }
//        .padding(.horizontal, 12)
//    }
//}
//
//
//
//// MARK: - Watchlist Row View
//struct WatchlistRowView: View {
//    let symbol: SymbolDTO
//    let onTap: () -> Void
//
//    
//    @State private var isPressed = false
//    
//    // Computed properties to simplify the complex expressions
//    private var isMarketOpen: Bool {
//        symbol.symbolStatus == .open
//    }
//    
//    private var statusIcon: String {
//        isMarketOpen ? "circle.circle.fill" : "moon.fill"
//    }
//    
//    private var statusColor: Color {
//        isMarketOpen ? AppColors.bullCandleGreen : AppColors.accentDarkColor
//    }
//    
//    
//    private var statusView: some View {
//        Group {
//            if isMarketOpen {
//                Image(systemName: statusIcon)
//                    .foregroundColor(statusColor)
//            } else {
//                Image(systemName: statusIcon)
//                    .symbolRenderingMode(.palette)
//                    .foregroundStyle(statusColor, .white)
//            }
//        }
//        .font(.caption2)
//        .fontWeight(.regular)
//    }
//    
//    private var isDirectionPositive: Bool{
//        symbol.isUp == true
//    }
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 12) {
//                VStack(spacing: 4) {
//                    Text(String(symbol.ticker.prefix(2)))
//                        .font(.caption2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//                    
//                }
//                .frame(width: 40, height: 40)
//                .background(Color.white.opacity(0.1))
//                .cornerRadius(8)
//
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Text(symbol.ticker)
//                            .font(.subheadline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        statusView
//                    }
//                    
//                    Text(symbol.name)
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.6))
//                }
//
//                Spacer()
//
//                VStack(alignment: .trailing, spacing: 4) {
//                    Text(symbol.price.formatted())
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .foregroundColor(AppColors.whiteText.opacity(0.9))
//                    Text("\(symbol.change.formatted())  \(symbol.changeFormatted)")
//                        .font(.footnote)
//                        .fontWeight(.regular)
//                        .foregroundColor(isDirectionPositive ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                }
//                .padding(.leading, 4)
//            }
//            .padding(.trailing, 16)
//            .padding(.leading, 8)
//            .padding(.vertical, 8)
//            .frame(minHeight: 56, alignment: .center)
//            .background(
//                RoundedRectangle(cornerRadius: 14)
//                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.02))
////                    .overlay(
////                        RoundedRectangle(cornerRadius: 14)
////                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1)
////                    )
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = pressing
//            }
//        }, perform: {})
//    }
//}

