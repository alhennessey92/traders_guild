//
//  StatGauge.swift
//  traders_guild
//
//  Radial percentage gauge used for accuracy / hit-rate dials. Pure SwiftUI
//  (no Charts framework) because Apple's `Gauge` doesn't expose enough styling
//  control for our theme tokens.
//

import SwiftUI

struct StatGauge: View {
    /// Progress in [0, 1].
    let progress: Double
    let centerText: String
    var captionText: String? = nil
    var tint: Color
    var trackTint: Color = AppColors.symbolDetailCardFill
    var size: CGFloat = 96
    var lineWidth: CGFloat = 10

    private var clamped: Double { max(0, min(1, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackTint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: clamped)

            VStack(spacing: 2) {
                Text(centerText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let captionText {
                    Text(captionText)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
    }
}
