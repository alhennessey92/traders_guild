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
    var onShowMarkerActivity: (() -> Void)? = nil

    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Add a Marker")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 10) {
                    if let onShowMarkerActivity {
                        Button(action: onShowMarkerActivity) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    MarkerSettingsButton()
                }
            }
            .padding(.top, 15)
            .padding(.bottom, 6)

            Text("Place markers on the chart to share insights with your guild.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 14)

            // MARK: - Prediction (reputation-affecting, full-width)
            MarkerButton(
                type: .predictionTarget,
                isActive: isMarkerPlacementActive(for: .predictionTarget),
                controlViewModel: controlViewModel
            )
            .padding(.bottom, 2)
            Text("Affects your reputation score. SL and TP are required.")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.leading, 4)
                .padding(.bottom, 14)

            // MARK: - Trade Ideas
            markerSectionHeader("Trade Ideas", subtitle: "Entry and exit levels")
            markerRow(.entry, .takeProfit)
            markerRow(.stopLoss, .exit)

            // MARK: - Analysis
            markerSectionHeader("Analysis", subtitle: "Technical chart marks")
            markerRow(.support, .resistance)
            markerRow(.trendline, .pattern)

            // MARK: - Signals & Observations
            markerSectionHeader("Signals", subtitle: "Alerts and observations")
            markerRow(.indicator, .volumeSpike)
            markerRow(.alert, .question)

            // MARK: - Notes & Social
            markerSectionHeader("Notes & Social", subtitle: "Communication and expression")
            markerRow(.note, .poll)
            markerRow(.emoji, .personal)
        }
    }

    // MARK: - Helpers

    private func markerSectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.bottom, 8)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func markerRow(_ left: RLMarkerType, _ right: RLMarkerType) -> some View {
        HStack(spacing: 8) {
            MarkerButton(
                type: left,
                isActive: isMarkerPlacementActive(for: left),
                controlViewModel: controlViewModel
            )
            MarkerButton(
                type: right,
                isActive: isMarkerPlacementActive(for: right),
                controlViewModel: controlViewModel
            )
        }
        .padding(.bottom, 4)
    }
    
    /// Check if marker placement is active for a specific type
    private func isMarkerPlacementActive(for type: RLMarkerType) -> Bool {
        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerType == type
    }
}

// MARK: - Marker Button Component

/// A button for selecting a marker type to place
/// Shows cancel state when this type is currently being placed
struct MarkerButton: View {
    let type: RLMarkerType
    let isActive: Bool
    @ObservedObject var controlViewModel: ChartControlViewModel

    var body: some View {
        Button {
            if isActive {
                controlViewModel.cancelMarkerPlacement()
            } else {
                controlViewModel.startMarkerPlacement(type: type)
            }
        } label: {
            HStack(spacing: 10) {
                if isActive {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                } else {
                    UnifiedMarkerBadge(
                        type: type,
                        displayColor: type.color,
                        size: 34
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isActive ? "Cancel" : type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !isActive {
                        Text(type.subtitle)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.red : type.color.opacity(0.06))
                    if !isActive {
                        // Type-colored leading accent bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(type.color.opacity(0.25))
                            .frame(width: 3)
                            .padding(.vertical, 6)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


