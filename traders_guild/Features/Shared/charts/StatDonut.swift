//
//  StatDonut.swift
//  traders_guild
//
//  Parts-of-whole donut chart (e.g. wins vs losses). Uses SwiftUI Charts'
//  SectorMark.
//

import SwiftUI
import Charts

struct StatDonutSlice: Identifiable {
    let label: String
    let value: Double
    let tint: Color
    var id: String { label }
}

struct StatDonut: View {
    let slices: [StatDonutSlice]
    var centerText: String? = nil
    var centerCaption: String? = nil
    var size: CGFloat = 96

    private var total: Double {
        slices.map(\.value).reduce(0, +)
    }

    var body: some View {
        ZStack {
            if total <= 0 {
                Circle()
                    .stroke(AppColors.symbolDetailCardFill, lineWidth: 10)
                    .frame(width: size, height: size)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value(slice.label, slice.value),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(2)
                    .foregroundStyle(slice.tint)
                }
                .chartLegend(.hidden)
                .frame(width: size, height: size)
            }

            VStack(spacing: 2) {
                if let centerText {
                    Text(centerText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                        .lineLimit(1)
                }
                if let centerCaption {
                    Text(centerCaption)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
        }
    }
}
