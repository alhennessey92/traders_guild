import SwiftUI

struct MarkerPlacementTimeframesTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    var mirrorSourceIndicators: [IndicatorPayload] = []
    var mirrorSourceDrawings: [ChartDrawing] = []
    var showsTitleHeader: Bool = true
    var showsMirrorButton: Bool = false

    @State private var limitWarning: String?
    @State private var contextInfoMessage: String?
    @State private var mirrorInfoMessage: String?

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
                if showsTitleHeader {
                    tabTitleHeader
                }

                if showsMirrorButton {
                    mirrorChartSetupButton
                }

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
                .fill(AppColors.statusTeal22)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.statusTeal95)
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

            if let mirrorInfoMessage {
                Text(mirrorInfoMessage)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            if let limitWarning {
                Text(limitWarning)
                    .font(.caption2)
                    .foregroundColor(AppColors.statusWarning95)
            }
        }
    }

    private var mirrorChartSetupButton: some View {
        Button {
            mirrorChartSetup()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror Chart Setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Copy current chart indicators and drawings to this marker")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity((mirrorSourceIndicators.isEmpty && mirrorSourceDrawings.isEmpty) ? 0.55 : 1)
        .disabled(mirrorSourceIndicators.isEmpty && mirrorSourceDrawings.isEmpty)
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
        let isActive = timeframe == currentChartTimeframe
        let canToggleLink = placementState.canAddTimeframe || isLinked

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(timeframe.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(timeframe.displayName)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                HStack(spacing: 6) {
                    Text(isLinked ? "Linked supporting panel" : "Add as supporting panel")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }
            }

            Spacer(minLength: 0)

            if isActive {
                statusBadge(
                    title: "ACTIVE",
                    textColor: AppColors.statusPositive95,
                    fillColor: AppColors.statusPositive20
                )
            }

            if !isActive {
                Button {
                    selectTimeframe(timeframe)
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(placementState.intent.color.opacity(0.95))
                }
                .buttonStyle(.plain)
            }

            Button {
                toggleTimeframeLink(timeframe)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLinked ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isLinked ? "Unlink" : "Link")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isLinked ? .white : AppColors.surfaceWhite88)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            isLinked
                                ? placementState.intent.color.opacity(0.42)
                                : AppColors.whiteText.opacity(0.09)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isLinked
                                        ? placementState.intent.color.opacity(0.72)
                                        : AppColors.whiteText.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canToggleLink)
            .opacity(canToggleLink ? 1 : 0.45)
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
                // Tappable label area — navigates to timeframe
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayShortName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                        Text(displayName)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }

                    Spacer(minLength: 0)

                    if isActive {
                        statusBadge(
                            title: "ACTIVE",
                            textColor: AppColors.statusPositive95,
                            fillColor: AppColors.statusPositive20
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let timeframe else { return }
                    selectTimeframe(timeframe)
                }

                if let timeframe, !isActive {
                    Button {
                        selectTimeframe(timeframe)
                    } label: {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(placementState.intent.color.opacity(0.95))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    placementState.removeTimeframeLink(payload.timeframe)
                    limitWarning = nil
                    contextInfoMessage = nil
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.statusNegative85)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
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

    private func statusBadge(title: String, textColor: Color, fillColor: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(fillColor))
    }

    private func selectTimeframe(_ timeframe: RLChartTimeframe) {
        onSelectTimeframe?(timeframe)
        contextInfoMessage = "Switched chart to \(timeframe.shortName)."
        limitWarning = nil
    }

    private func toggleTimeframeLink(_ timeframe: RLChartTimeframe) {
        contextInfoMessage = nil
        mirrorInfoMessage = nil

        let backendValue = timeframe.toBackendString()
        if placementState.isTimeframeLinked(backendValue) {
            placementState.removeTimeframeLink(backendValue)
            limitWarning = nil
            contextInfoMessage = "Removed \(timeframe.shortName) linked panel."
            return
        }

        if placementState.upsertTimeframeLink(backendValue) {
            limitWarning = nil
            contextInfoMessage = "Linked \(timeframe.shortName) panel."
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

    private func mirrorChartSetup() {
        let indicatorResult = placementState.attachActiveChartIndicators(mirrorSourceIndicators)
        let drawingResult = placementState.attachActiveChartDrawings(mirrorSourceDrawings)
        let totalAdded = indicatorResult.added + drawingResult.added

        if totalAdded > 0 {
            var mirroredParts: [String] = []
            if indicatorResult.added > 0 {
                mirroredParts.append("\(indicatorResult.added) indicator\(indicatorResult.added == 1 ? "" : "s")")
            }
            if drawingResult.added > 0 {
                mirroredParts.append("\(drawingResult.added) drawing\(drawingResult.added == 1 ? "" : "s")")
            }
            mirrorInfoMessage = "Mirrored \(mirroredParts.joined(separator: " and ")) from chart."
        } else {
            mirrorInfoMessage = "No new chart indicators or drawings to mirror."
        }

        if indicatorResult.blockedByLimit || drawingResult.blockedByLimit {
            limitWarning = drawingResult.blockedByLimit
                ? placementState.limitMessage(for: .drawingOverlays)
                : placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
        } else {
            limitWarning = nil
        }
    }
}

private extension MarkerComponentPayload {
    var timeframeValue: String? {
        guard case let .timeframeLink(payload) = self else { return nil }
        return payload.timeframe
    }
}
