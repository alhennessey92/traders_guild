//
//  chartSheetSymbolView.swift
//  traders_guild
//
//  Created by Al Hennessey on 07/12/2025.
//
import SwiftUI
// MARK: - Main Indicator Settings Content (for MainView bottom sheet)

/// The indicator content view for ChartBottomSheet
/// Drop this into your indicatorContent in MainView
struct chartSheetSymbolView: View {
    /// Chart view model that coordinates chart state and data
    @ObservedObject var chartViewModel: ChartViewModel


    var body: some View {
        VStack(spacing: 20) {

            // SECTION: Current Symbol Info
            if let symbol = chartViewModel.currentSymbol {
                VStack(spacing: 12) {
                    HStack(alignment: .top) {
                        // Symbol details
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: symbol.assetClass.icon)
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(symbol.displayName)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    Text(symbol.symbol)
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.caption)
                                }
                            }
                            
                            Text(symbol.assetClass.rawValue)
                                .foregroundColor(.white.opacity(0.5))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Current price
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
                                .foregroundColor(.white)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(chartViewModel.currentTimeframe.displayName)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            
            // Loading indicator
            if chartViewModel.isLoadingData {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading data...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
            }
            
            // SECTION: Timeframe Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeframe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Grouped by category
                VStack(spacing: 12) {
                    // Minutes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.m1, .m5, .m15, .m30], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                    
                    // Hours
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hours")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.h1, .h4], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                    
                    // Daily+
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daily & Weekly")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.d1, .w1, .mn], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            
            // SECTION: Watchlist
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Watchlist")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(chartViewModel.combinedWatchlist.count) symbols")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if chartViewModel.combinedWatchlist.isEmpty {
                    Text("No symbols in watchlist")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(chartViewModel.combinedWatchlist) { symbol in
                            SymbolRow(
                                symbol: symbol,
                                isSelected: chartViewModel.currentSymbol?.id == symbol.id
                            ) {
                                chartViewModel.setSymbol(symbol)
                            }
                        }
                    }
                }
            }
        }
    }
}



// MARK: - Supporting Views

struct SymbolRow: View {
    let symbol: TradingSymbol
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol.assetClass.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.title3)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.displayName)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    HStack(spacing: 6) {
                        Text(symbol.symbol)
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("•")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text(symbol.assetClass.rawValue)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
                        : [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}


struct TimeframeButton: View {
    let timeframe: ChartTimeframe
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.shortName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ?
                    Color.blue :
                    Color.white.opacity(0.1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
