//
//  chartSheetMarkersView.swift
//  traders_guild
//
//  Created by Al Hennessey on 07/12/2025.
//

import SwiftUI

// MARK: - Main Indicator Settings Content (for MainView bottom sheet)

/// The indicator content view for ChartBottomSheet
/// Drop this into your indicatorContent in MainView
struct chartSheetMarkersView: View {
    /// Chart view model that coordinates chart state and data
    @ObservedObject var chartViewModel: ChartViewModel
    // MARK: - Chart Control ViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel
    

    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack{
                    Text("Add a Marker")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 15)
                    
                    Spacer()
                    
                    MarkerSettingsButton()
                        .padding(.trailing, 15)
                        .padding(.top, 15)
                    
                }
                
                
                Text("Place markers on the chart to share insights with your guild. Each candle can have one of each marker type.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                VStack(spacing: 8) {
                    
                    // MARK: - Core Markers Section
                    Text("Core Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .note,
                            isActive: isMarkerPlacementActive(for: .note),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .question,
                            isActive: isMarkerPlacementActive(for: .question),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .alert,
                            isActive: isMarkerPlacementActive(for: .alert),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .entry,
                            isActive: isMarkerPlacementActive(for: .entry),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .exit,
                            isActive: isMarkerPlacementActive(for: .exit),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    // MARK: - Analysis Markers Section
                    Text("Analysis Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .support,
                            isActive: isMarkerPlacementActive(for: .support),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .resistance,
                            isActive: isMarkerPlacementActive(for: .resistance),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .indicator,
                            isActive: isMarkerPlacementActive(for: .indicator),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .trendline,
                            isActive: isMarkerPlacementActive(for: .trendline),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .pattern,
                            isActive: isMarkerPlacementActive(for: .pattern),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .volumeSpike,
                            isActive: isMarkerPlacementActive(for: .volumeSpike),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    // MARK: - Prediction Markers Section
                    Text("Prediction Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .predictionTarget,
                            isActive: isMarkerPlacementActive(for: .predictionTarget),
                            controlViewModel: controlViewModel
                        )
                        
//                        Spacer()
//                        Spacer()
                    }
                    
                    // MARK: - Social Markers Section
                    Text("Social Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .emoji,
                            isActive: isMarkerPlacementActive(for: .emoji),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .poll,
                            isActive: isMarkerPlacementActive(for: .poll),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .personal,
                            isActive: isMarkerPlacementActive(for: .personal),
                            controlViewModel: controlViewModel
                        )
                    }
                    
//                    // MARK: - Marker Settings Section
//                    Divider()
//                        .background(Color.white.opacity(0.2))
//                        .padding(.top, 16)
//                    
//                    HStack {
//                        Text("Marker Display Settings")
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                        
////                        Spacer()
////                        
////                        MarkerSettingsButton()
//                    }
//                    .padding(.top, 8)
//                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    /// Check if marker placement is active for a specific type
    private func isMarkerPlacementActive(for type: MarkerType) -> Bool {
        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerType == type
    }
}

// MARK: - Marker Button Component

/// A button for selecting a marker type to place
/// Shows cancel state when this type is currently being placed
struct MarkerButton: View {
    let type: MarkerType
    let isActive: Bool
    @ObservedObject var controlViewModel: ChartControlViewModel
    
    var body: some View {
        Button {
            if isActive {
                // Currently placing this type - cancel
                controlViewModel.cancelMarkerPlacement()
            } else {
                // Start placing this type
                controlViewModel.startMarkerPlacement(type: type)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isActive ? "xmark.circle" : type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isActive ? .white : type.color)
                
                Text(isActive ? "Cancel" : type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isActive ?
                Color.red :
                Color.white.opacity(0.05)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}



