//
//  StatProgressBar.swift
//  traders_guild
//
//  Horizontal progress bar with label + value, extracted verbatim from the
//  previously-inline BreakdownBarRow so it can be reused by the guild
//  statistics screen and the reputation/accuracy breakdown sheets.
//

import SwiftUI

struct StatProgressBar: View {
    let label: String
    let valueText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                Text(valueText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(tint)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.symbolDetailCardFill)
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 8)
        }
    }
}
