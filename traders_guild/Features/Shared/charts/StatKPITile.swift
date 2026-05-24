//
//  StatKPITile.swift
//  traders_guild
//
//  Primary KPI tile: label, big value, optional delta chip, optional sparkline.
//  Replaces the old StatMetricRow used by the guild statistics screen and the
//  user profile / global stat grids.
//

import SwiftUI

struct StatKPITile: View {
    let label: String
    let value: String
    var tint: Color = AppColors.whiteText
    var delta: String? = nil
    var deltaTint: Color? = nil
    var sparkline: [Double] = []
    var sparklineTint: Color? = nil
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(0.4)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let delta {
                    Text(delta)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(deltaTint ?? AppColors.greyText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill((deltaTint ?? AppColors.greyText).opacity(0.12))
                        )
                        .lineLimit(1)
                }
            }

            Text(value)
                .font(compact ? .title3 : .title2)
                .fontWeight(.bold)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !sparkline.isEmpty {
                StatSparkline(
                    values: sparkline,
                    tint: sparklineTint ?? tint,
                    height: compact ? 22 : 28
                )
            }
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.guildStatisticsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.guildStatisticsCardStroke, lineWidth: 1)
                )
        )
    }
}
