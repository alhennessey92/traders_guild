import SwiftUI

@available(*, deprecated, message: "ToolPicker sidebar replaced by bottom placement tabs and intent action strip.")
struct ToolPickerView: View {
    @ObservedObject var placementState: MarkerPlacementState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(placementState.availableGroups()) { group in
                        Button {
                            placementState.activeTool = group
                            if !placementState.availableOptions(for: group).contains(where: { $0.rawValue == placementState.activeSubTool }) {
                                placementState.activeSubTool = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: group.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(group.title)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        placementState.activeTool == group
                                            ? placementState.intent.color.opacity(0.3)
                                            : AppColors.whiteText.opacity(0.06)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let activeTool = placementState.activeTool {
                Divider().overlay(AppColors.whiteText.opacity(0.1))
                ToolOptionStrip(activeTool: activeTool, placementState: placementState)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.sheetBackground.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ToolOptionStrip: View {
    let activeTool: MarkerToolGroup
    @ObservedObject var placementState: MarkerPlacementState

    var body: some View {
        let options = placementState.availableOptions(for: activeTool)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Options")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)

            if options.isEmpty {
                Text("No options for \(placementState.intent.displayName)")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(options) { option in
                            let isSelected = placementState.activeSubTool == option.rawValue
                            Button {
                                placementState.applyToolOption(option)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 14)
                                    Text(option.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .foregroundColor(AppColors.primaryForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(
                                            isSelected
                                                ? placementState.intent.color.opacity(0.38)
                                                : AppColors.whiteText.opacity(0.08)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(
                                            isSelected
                                                ? placementState.intent.color.opacity(0.55)
                                                : AppColors.whiteText.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }
}
