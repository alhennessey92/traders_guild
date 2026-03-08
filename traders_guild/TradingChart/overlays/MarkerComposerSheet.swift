import SwiftUI

@available(*, deprecated, message: "Use the inline placement flow in TradingChartView/MainView.")
struct MarkerComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var markerManager: MarkerManager
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let chartData: ChartDataManager
    let candles: [RLCandleDTO]
    let markerIntent: RLMarkerIntent
    let initialTargetPrice: Double?
    let initialHorizontalLinePrice: Double?
    let initialStopLossPrice: Double?

    @StateObject private var placementState = MarkerPlacementState()

    var body: some View {
        VStack(spacing: 10) {
            MarkerPlacementMode(
                placementState: placementState,
                chartPreview: AnyView(previewLayer),
                onCancel: { dismiss() },
                onPlace: placeMarker
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    intentGrid
                    componentEditor
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(
            ZStack {
                Color.clear.background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .onAppear(perform: configureInitialState)
    }

    private var previewLayer: some View {
        GeometryReader { geo in
            ZStack {
                GhostPreviewLayer(
                    placementState: placementState,
                    yForPrice: previewYPosition(for:),
                    width: geo.size.width
                )
                .padding(.horizontal, 8)

                VStack {
                    Spacer()
                    Text("Ghost Preview")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func previewYPosition(for markerPrice: Double) -> CGFloat? {
        let zonePrices = placementState.components.compactMap { draft -> [Double]? in
            if case let .drawingZone(payload) = draft.payload {
                return [payload.topPrice, payload.bottomPrice]
            }
            return nil
        }.flatMap { $0 }
        let trendlinePrices = placementState.components.compactMap { draft -> [Double]? in
            if case let .drawingTrendline(payload) = draft.payload {
                return [payload.startPrice, payload.endPrice]
            }
            return nil
        }.flatMap { $0 }
        let prices = placementState.components.compactMap { $0.payload.levelPrice } + zonePrices + trendlinePrices + [price]
        guard let minPrice = prices.min(), let maxPrice = prices.max() else { return nil }
        let spread = max(maxPrice - minPrice, 0.0000001)
        let normalized = (markerPrice - minPrice) / spread
        return 96 - (normalized * 82)
    }

    private var intentGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(RLMarkerIntent.allCases, id: \.rawValue) { intent in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        placementState.setIntent(intent)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: intent.icon)
                            .font(.headline)
                        Text(intent.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(intent.rawValue)
                            .font(.caption2)
                            .opacity(0.65)
                    }
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((placementState.intent == intent ? intent.color.opacity(0.42) : AppColors.whiteText.opacity(0.08)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(placementState.intent == intent ? intent.color.opacity(0.75) : AppColors.whiteText.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var componentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Components")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(placementState.components) { component in
                        HStack(spacing: 6) {
                            Image(systemName: component.componentType.icon)
                                .font(.caption2)
                            Text(component.componentType.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                            if let levelPrice = component.payload.levelPrice {
                                Text(String(format: "%.2f", levelPrice))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(component.componentType.color.opacity(0.95))
                            }
                            Button {
                                placementState.removeComponent(component.componentType)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .opacity(component.componentType == .anchor ? 0.2 : 1.0)
                            .disabled(component.componentType == .anchor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(component.componentType.color.opacity(0.14)))
                        .foregroundColor(.white)
                    }
                }
            }

            componentQuickActions

            if placementState.intent == .setup {
                setupLevelPreview
            }

            if let anchor = placementState.components.first(where: { $0.componentType == .anchor })?.payload.levelPrice {
                Text("Anchor: \(chartData.formatPrice(anchor))")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.whiteText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var componentQuickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            let defaultGroup = placementState.intent == .news ? MarkerToolGroup.link : MarkerToolGroup.levels
            let group = placementState.activeTool ?? defaultGroup
            let options = placementState.availableOptions(for: group)

            if options.isEmpty {
                Text("Select an action to add components")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(options) { option in
                        Button {
                            placementState.applyToolOption(option)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: option.icon)
                                    .font(.caption2)
                                Text(option.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var setupLevelPreview: some View {
        let entry = placementState.componentPrice(.levelEntry)
        let sl = placementState.componentPrice(.levelSl)
        let tp = placementState.componentPrice(.levelTp)
        if let entry, let sl, let tp {
            let values = [entry, sl, tp]
            let minPrice = values.min() ?? entry
            let maxPrice = values.max() ?? entry
            let spread = max(maxPrice - minPrice, 0.0000001)

            VStack(alignment: .leading, spacing: 8) {
                Text("Setup Ladder")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                GeometryReader { geo in
                    let topY: (Double) -> CGFloat = { value in
                        let normalized = (value - minPrice) / spread
                        return geo.size.height - (normalized * geo.size.height)
                    }
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.whiteText.opacity(0.05))
                            .frame(height: geo.size.height)
                            .cornerRadius(8)

                        ladderLine(label: "TP", price: tp, color: RLComponentType.levelTp.color, y: topY(tp), width: geo.size.width)
                        ladderLine(label: "Entry", price: entry, color: RLComponentType.levelEntry.color, y: topY(entry), width: geo.size.width)
                        ladderLine(label: "SL", price: sl, color: RLComponentType.levelSl.color, y: topY(sl), width: geo.size.width)
                    }
                }
                .frame(height: 90)
            }
        }
    }

    private func ladderLine(label: String, price: Double, color: Color, y: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
            Spacer()
            Text(String(format: "%.5f", price))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 20)
        .background(
            Capsule()
                .fill(color.opacity(0.16))
                .overlay(Capsule().stroke(color.opacity(0.55), lineWidth: 1))
        )
        .offset(y: y - 10)
    }

    private func configureInitialState() {
        placementState.reset(to: markerIntent, anchorTime: timestamp, anchorPrice: price)

        if let initialHorizontalLinePrice {
            let levelType: RLComponentType = markerIntent == .setup ? .levelEntry : .levelSupport
            switch levelType {
            case .levelEntry:
                placementState.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: initialHorizontalLinePrice, label: nil)))
            default:
                placementState.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: initialHorizontalLinePrice, label: nil)))
            }
        }
        if let initialTargetPrice {
            placementState.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: initialTargetPrice, label: nil)))
        }
        if let initialStopLossPrice {
            placementState.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: initialStopLossPrice, label: nil)))
        }
    }

    private func placeMarker() {
        guard placementState.isValid, let symbolId = chartData.currentSymbol?.id else { return }
        let request = placementState.buildCreateRequest(
            symbolId: symbolId,
            timeframe: chartData.currentTimeframe.toBackendString()
        )

        Task {
            let success = await markerManager.addMarkerV2(
                request: request,
                candleIndex: candleIndex,
                candles: candles
            )

            if success {
                dismiss()
            }
        }
    }
}
