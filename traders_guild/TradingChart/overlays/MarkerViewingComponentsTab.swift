import Foundation
import SwiftUI

struct MarkerViewingComponentsTab: View {
    let marker: ChartMarkerUI

    private var orderedComponents: [RLMarkerComponentDTO] {
        marker.components.sorted {
            if $0.ordering != $1.ordering { return $0.ordering < $1.ordering }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private var drawingComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum?.isDrawing == true }
    }

    private var indicatorComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum == .indicator }
    }

    private var timeframeComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum == .timeframeLink }
    }

    private var indicatorPanelCount: Int {
        indicatorComponents.reduce(0) { partial, component in
            guard case let .indicator(payload) = component.payload else { return partial }
            return partial + (isPanelIndicator(payload.name) ? 1 : 0)
        }
    }

    private var indicatorOverlayCount: Int {
        max(0, indicatorComponents.count - indicatorPanelCount)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                overviewCard
                indicatorsSection
                drawingsSection
                timeframesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Component Overview")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                overviewBadge(title: "Total", value: "\(orderedComponents.count)")
                overviewBadge(title: "Indicators", value: "\(indicatorComponents.count)")
                overviewBadge(title: "Drawings", value: "\(drawingComponents.count)")
                overviewBadge(title: "Timeframes", value: "\(timeframeComponents.count)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private var indicatorsSection: some View {
        sectionCard(
            title: "Indicators",
            subtitle: "Attached studies and panel usage",
            icon: "waveform.path.ecg",
            tint: Color(hex: "#F59E0B") ?? .orange,
            countText: "\(indicatorComponents.count)"
        ) {
            VStack(spacing: 8) {
                if indicatorComponents.isEmpty {
                    emptyRow("No indicators attached")
                } else {
                    ForEach(indicatorComponents) { component in
                        indicatorRow(component)
                    }
                }

                if !indicatorComponents.isEmpty {
                    HStack(spacing: 8) {
                        smallInfoBadge(
                            text: "Panel \(indicatorPanelCount)",
                            tint: Color(hex: "#F97316") ?? .orange
                        )
                        smallInfoBadge(
                            text: "Overlay \(indicatorOverlayCount)",
                            tint: Color(hex: "#0EA5E9") ?? .cyan
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var drawingsSection: some View {
        sectionCard(
            title: "Drawings",
            subtitle: "Trendline and zone coordinates",
            icon: "pencil.and.ruler",
            tint: Color(hex: "#14B8A6") ?? .teal,
            countText: "\(drawingComponents.count)"
        ) {
            VStack(spacing: 8) {
                if drawingComponents.isEmpty {
                    emptyRow("No drawings attached")
                } else {
                    ForEach(drawingComponents) { component in
                        drawingRow(component)
                    }
                }
            }
        }
    }

    private var timeframesSection: some View {
        sectionCard(
            title: "Timeframes",
            subtitle: "Linked horizon context",
            icon: "clock.fill",
            tint: Color(hex: "#38BDF8") ?? .cyan,
            countText: "\(timeframeComponents.count)"
        ) {
            VStack(spacing: 8) {
                if timeframeComponents.isEmpty {
                    emptyRow("No linked timeframes")
                } else {
                    ForEach(timeframeComponents) { component in
                        timeframeRow(component)
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        countText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint.opacity(0.24))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(tint)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Text(countText)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.33))
                            .overlay(
                                Capsule()
                                    .stroke(tint.opacity(0.58), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), AppColors.whiteText.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(tint.opacity(0.26), lineWidth: 1)
                    )
            )

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private func overviewBadge(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private func indicatorRow(_ component: RLMarkerComponentDTO) -> some View {
        let payload: IndicatorPayload? = {
            guard case let .indicator(value) = component.payload else { return nil }
            return value
        }()
        let indicatorName = payload?.name ?? "Indicator"
        let panel = isPanelIndicator(indicatorName)
        let isPrimary = payload?.isPrimary == true
        let typeBadgeTint = panel
            ? (Color(hex: "#F97316") ?? .orange)
            : (Color(hex: "#0EA5E9") ?? .cyan)

        return HStack(spacing: 10) {
            Circle()
                .fill((component.componentTypeEnum?.color ?? (Color(hex: "#F59E0B") ?? .orange)).opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: indicatorIcon(for: indicatorName))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(component.componentTypeEnum?.color ?? .orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(indicatorName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text(isPrimary ? "Primary indicator" : "Attached indicator")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(panel ? "Panel" : "Overlay")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(typeBadgeTint.opacity(0.45))
                    )

                if isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#FBBF24") ?? .yellow)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func drawingRow(_ component: RLMarkerComponentDTO) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill((component.componentTypeEnum?.color ?? .teal).opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: component.componentTypeEnum?.icon ?? "pencil.and.ruler")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(component.componentTypeEnum?.color ?? .teal)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(component.componentTypeEnum?.displayName ?? component.componentType)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text(drawingCoordinateSummary(component))
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func timeframeRow(_ component: RLMarkerComponentDTO) -> some View {
        let payload: TimeframeLinkPayload? = {
            guard case let .timeframeLink(value) = component.payload else { return nil }
            return value
        }()
        let backend = payload?.timeframe ?? ""
        let resolved = RLChartTimeframe.fromBackendString(backend)
        let shortName = resolved?.shortName ?? backend.uppercased()
        let displayName = resolved?.displayName ?? backend.uppercased()
        let note = payload?.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(spacing: 10) {
            Circle()
                .fill((Color(hex: "#38BDF8") ?? .cyan).opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#38BDF8") ?? .cyan)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(shortName)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((Color(hex: "#38BDF8") ?? .cyan).opacity(0.42)))

                    Text(displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                if !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func smallInfoBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.4)))
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(AppColors.greyText.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func drawingCoordinateSummary(_ component: RLMarkerComponentDTO) -> String {
        switch component.payload {
        case .drawingTrendline(let payload):
            return "\(formattedPrice(payload.startPrice)) -> \(formattedPrice(payload.endPrice))"
        case .drawingZone(let payload):
            return "Top \(formattedPrice(payload.topPrice)) / Bottom \(formattedPrice(payload.bottomPrice))"
        default:
            return "Coordinates unavailable"
        }
    }

    private func sectionCardBackground(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [AppColors.whiteText.opacity(0.07), AppColors.whiteText.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1)
            )
    }

    private func indicatorIcon(for name: String) -> String {
        let normalized = name.uppercased()
        if normalized.contains("RSI") { return "gauge" }
        if normalized.contains("MACD") { return "chart.bar.fill" }
        if normalized.contains("STOCH") { return "waveform.path.ecg.rectangle" }
        if normalized.contains("CCI") { return "chart.xyaxis.line" }
        if normalized.contains("WILLIAMS") { return "chart.line.uptrend.xyaxis" }
        if normalized.contains("ATR") { return "waveform.path.badge.plus" }
        if normalized.contains("VOLUME") { return "chart.bar.xaxis" }
        return "waveform.path.ecg"
    }

    private func isPanelIndicator(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.contains("VWAP") || normalized.contains("WEIGHTED AVERAGE PRICE") {
            return false
        }
        return normalized.contains("RSI")
            || normalized.contains("MACD")
            || normalized.contains("STOCH")
            || normalized.contains("CCI")
            || normalized.contains("WILLIAMS")
            || normalized.contains("ATR")
            || normalized.contains("VOLUME")
    }

    private func formattedPrice(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}
