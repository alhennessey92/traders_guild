import Foundation
import SwiftUI

struct MarkerViewingInfoBox: View {
    let marker: ChartMarkerUI
    let chartWidth: CGFloat
    let yAxisWidth: CGFloat
    @Binding var isCollapsed: Bool
    let formatPrice: (Double) -> String
    let isSubmittingPollVote: Bool
    let submittingPollVoteOptionId: UUID?
    let onVote: (UUID, UUID) -> Void

    private var expandedWidth: CGFloat {
        max(240, chartWidth - yAxisWidth - 12)
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedStrip
            } else {
                expandedPanel
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
    }

    private var expandedPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            collapseHandle(icon: "chevron.left", hint: "Collapse")
                .onTapGesture { toggleCollapse() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: expandedWidth, alignment: .leading)
        .background(panelBackground(cornerRadius: 12))
    }

    private var collapsedStrip: some View {
        VStack(spacing: 6) {
            UnifiedMarkerBadge(
                intent: marker.intent,
                alertSeverity: marker.alertSeverity,
                sizeToken: .tiny
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.surfaceWhite84)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(width: 30)
        .background(panelBackground(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: toggleCollapse)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            UnifiedMarkerBadge(
                intent: marker.intent,
                alertSeverity: marker.alertSeverity,
                sizeToken: .small
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(marker.intent.displayName) Marker")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("Details")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.surfaceWhite74)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch marker.intent {
        case .setup:
            VStack(alignment: .leading, spacing: 7) {
                valueRow(
                    title: "Entry",
                    value: formatPrice(marker.entryPrice ?? marker.price),
                    color: RLComponentType.levelEntry.color
                )
                if let tp = marker.targetPrice {
                    valueRow(
                        title: "Take Profit",
                        value: formatPrice(tp),
                        color: RLComponentType.levelTp.color
                    )
                }
                if let sl = marker.stopLossPrice {
                    valueRow(
                        title: "Stop Loss",
                        value: formatPrice(sl),
                        color: RLComponentType.levelSl.color
                    )
                }
            }

        case .analysis:
            bodyText(marker.note, placeholder: "No analysis text provided.")

        case .alert:
            VStack(alignment: .leading, spacing: 7) {
                if let severity = marker.alertSeverity {
                    HStack(spacing: 7) {
                        Image(systemName: severity.markerIcon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(severity.rawValue)
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(severity.color.opacity(0.45))
                            .overlay(
                                Capsule()
                                    .stroke(severity.color.opacity(0.68), lineWidth: 1)
                            )
                    )
                }
                bodyText(marker.note, placeholder: "No alert note.")
            }

        case .question:
            bodyText(marker.note, placeholder: "No question provided.")

        case .poll:
            pollContent

        case .news:
            bodyText(newsURL ?? marker.note, placeholder: "No link or note provided.")

        case .reaction:
            let emoji = marker.selectedEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if emoji.isEmpty {
                bodyText(nil, placeholder: "No reaction selected.")
            } else {
                HStack(spacing: 8) {
                    Text(emoji)
                        .font(.system(size: 22))
                    Text("Reaction selected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite80)
                    Spacer(minLength: 0)
                }
            }

        case .personal:
            bodyText(marker.note, placeholder: "Private marker.")
        }
    }

    private var pollContent: some View {
        let question = marker.pollQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let options = marker.pollOptions ?? []
        let totalVotes = max(0, options.reduce(0) { $0 + $1.voteCount })

        return VStack(alignment: .leading, spacing: 7) {
            if !question.isEmpty {
                Text(question)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.surfaceWhite92)
                    .lineLimit(3)
            }

            if options.isEmpty {
                bodyText(nil, placeholder: "No poll options.")
            } else {
                ForEach(options) { option in
                    pollOptionRow(option: option, totalVotes: totalVotes)
                }
            }
        }
    }

    private func pollOptionRow(option: RLPollOptionDTO, totalVotes: Int) -> some View {
        let isSelected = marker.userPollVote == option.id || option.hasVoted
        let isSubmitting = isSubmittingPollVote && submittingPollVoteOptionId == option.id
        let percentage = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

        return Button {
            onVote(marker.id, option.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.text)
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.65)
                            .tint(AppColors.surfaceWhite88)
                    } else {
                        Text("\(option.voteCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.surfaceWhite78)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.surfaceWhite10)
                        Capsule()
                            .fill(isSelected ? AppColors.accentColor.opacity(0.9) : AppColors.surfaceWhite32)
                            .frame(width: max(3, geometry.size.width * percentage))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? AppColors.accentColor.opacity(0.2) : AppColors.surfaceWhite08)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isSelected ? AppColors.accentColor.opacity(0.46) : AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmittingPollVote)
    }

    private func valueRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(AppColors.surfaceWhite08)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }

    private func bodyText(_ text: String?, placeholder: String) -> some View {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Text(value.isEmpty ? placeholder : value)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(value.isEmpty ? AppColors.surfaceWhite66 : AppColors.surfaceWhite92)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(AppColors.surfaceWhite08)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppColors.surfaceBlack50)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppColors.surfaceWhite18, lineWidth: 1)
        )
    }

    private func collapseHandle(icon: String, hint: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.surfaceWhite94)
            .frame(width: 18, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.surfaceWhite12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                    )
            )
    }

    private func toggleCollapse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCollapsed.toggle()
        }
    }

    private var newsURL: String? {
        for component in marker.components {
            guard component.componentTypeEnum == .linkURL,
                  case let .link(payload) = component.payload else {
                continue
            }
            let value = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
