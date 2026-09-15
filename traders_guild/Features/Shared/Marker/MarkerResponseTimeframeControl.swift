import SwiftUI

/// Change the response's chart interval without leaving or resetting its draft.
struct MarkerResponseTimeframeControl: View {
    let timeframe: RLChartTimeframe
    let isLoading: Bool
    let onSelect: (RLChartTimeframe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                ForEach(RLChartTimeframe.allCases, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        if option == timeframe {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                    Text("Response timeframe")
                    Spacer(minLength: 4)
                    if isLoading {
                        ProgressView()
                    }
                    Text(timeframe.shortName).fontWeight(.semibold)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.primaryForeground)
                .padding(12)
                .background(AppColors.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)
            .accessibilityIdentifier("marker.response.timeframe")
            .accessibilityLabel("Response timeframe")
            .accessibilityValue(isLoading ? "Loading \(timeframe.displayName)" : timeframe.displayName)
            Text("Choose where to place your response. The original marker stays on its own timeframe.")
                .font(.caption)
                .foregroundStyle(AppColors.greyText)
        }
    }
}
