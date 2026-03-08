import SwiftUI

struct MarkerPlacementTimeframesTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?

    @State private var limitWarning: String?
    @State private var contextInfoMessage: String?

    private var orderedLinkedDrafts: [MarkerComponentDraft] {
        placementState.timeframeLinkDrafts.sorted { lhs, rhs in
            let lhsRank = timeframeOrderIndex(lhs.payload.timeframeValue)
            let rhsRank = timeframeOrderIndex(rhs.payload.timeframeValue)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                tabTitleHeader
                headerSection
                allTimeframesSection
                linkedTimeframesSection
            }
            .padding(.trailing, 2)
        }
    }

    private var tabTitleHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.teal.opacity(0.22))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.teal.opacity(0.95))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Timeframes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Link supporting timeframes to this marker")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(placementState.timeframeLinkCount) / 2 linked")
                .font(.caption2)
                .foregroundColor(AppColors.whiteText.opacity(0.9))

            if let contextInfoMessage {
                Text(contextInfoMessage)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            if let limitWarning {
                Text(limitWarning)
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.95))
            }
        }
    }

    private var allTimeframesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Timeframes")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            ForEach(RLChartTimeframe.allCases, id: \.rawValue) { timeframe in
                timeframeRow(timeframe)
            }
        }
    }

    private var linkedTimeframesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currently Linked")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            if orderedLinkedDrafts.isEmpty {
                Text("No linked timeframes.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            } else {
                ForEach(orderedLinkedDrafts) { draft in
                    linkedDraftRow(draft)
                }
            }
        }
    }

    private func timeframeRow(_ timeframe: RLChartTimeframe) -> some View {
        let backendValue = timeframe.toBackendString()
        let isLinked = placementState.isTimeframeLinked(backendValue)
        let canAttach = placementState.canAddTimeframe || isLinked
        let isActive = timeframe == currentChartTimeframe

        return HStack(spacing: 10) {
            Button {
                onSelectTimeframe?(timeframe)
                contextInfoMessage = "Switched chart to \(timeframe.shortName)."
                limitWarning = nil
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeframe.shortName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text(timeframe.displayName)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green.opacity(0.95))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.green.opacity(0.2)))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                toggleTimeframeLink(timeframe)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isLinked ? "link.circle.fill" : "link.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isLinked ? "Linked" : "Link")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            isLinked
                                ? placementState.intent.color.opacity(0.42)
                                : AppColors.whiteText.opacity(0.09)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLinked
                                ? placementState.intent.color.opacity(0.6)
                                : AppColors.whiteText.opacity(0.08),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!isLinked && !canAttach)
            .opacity((!isLinked && !canAttach) ? 0.45 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive
                                ? placementState.intent.color.opacity(0.45)
                                : AppColors.whiteText.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    @ViewBuilder
    private func linkedDraftRow(_ draft: MarkerComponentDraft) -> some View {
        if case let .timeframeLink(payload) = draft.payload {
            let timeframe = RLChartTimeframe.fromBackendString(payload.timeframe)
            let displayShortName = timeframe?.shortName ?? payload.timeframe.uppercased()
            let displayName = timeframe?.displayName ?? payload.timeframe.uppercased()
            let isActive = timeframe == currentChartTimeframe

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayShortName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                    Text(displayName)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.green.opacity(0.2)))
                }

                Spacer(minLength: 0)

                if let timeframe {
                    Button("Open") {
                        onSelectTimeframe?(timeframe)
                        contextInfoMessage = "Switched chart to \(timeframe.shortName)."
                        limitWarning = nil
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(placementState.intent.color)
                    .buttonStyle(.plain)
                }

                Button {
                    placementState.removeComponent(id: draft.id)
                    limitWarning = nil
                    contextInfoMessage = nil
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func toggleTimeframeLink(_ timeframe: RLChartTimeframe) {
        contextInfoMessage = nil

        let backendValue = timeframe.toBackendString()
        if placementState.isTimeframeLinked(backendValue) {
            placementState.removeTimeframeLink(backendValue)
            limitWarning = nil
            return
        }

        if placementState.upsertTimeframeLink(backendValue) {
            limitWarning = nil
            return
        }

        limitWarning = placementState.limitMessage(for: .timeframeLinks)
        HapticFeedback.light.trigger()
    }

    private func timeframeOrderIndex(_ backendTimeframe: String?) -> Int {
        guard let backendTimeframe,
              let timeframe = RLChartTimeframe.fromBackendString(backendTimeframe),
              let index = RLChartTimeframe.allCases.firstIndex(of: timeframe) else {
            return Int.max
        }
        return index
    }
}

private extension MarkerComponentPayload {
    var timeframeValue: String? {
        guard case let .timeframeLink(payload) = self else { return nil }
        return payload.timeframe
    }
}
