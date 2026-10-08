import SwiftUI

/// Add context: one screen, in the Components sheet's tab layout. What the
/// marker already carries sits on top as chips (tap to edit, ✕ to remove);
/// below, a tab per kind of context, each browsable in place. Indicators
/// open their settings editor; drawings and levels go to the chart; nothing
/// presents another sheet.
struct MarkerWorkspaceContextScreen: View {
    @ObservedObject var placementState: MarkerPlacementState
    let currentChartTimeframe: RLChartTimeframe?
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let onBeginInteractiveDrawing: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tab: MarkerContextTab { placementState.workspaceContextTab }

    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) {
            VStack(alignment: .leading, spacing: 14) {
                attachedStrip
                tabBar
                Group {
                    switch tab {
                    case .indicators: indicators
                    case .drawings: drawings
                    case .timeframes: timeframes
                    case .notes: notes
                    }
                }
                .id(tab)
                .transition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
        }
    }

    // MARK: On this marker

    private var contextDrafts: [MarkerComponentDraft] {
        placementState.components.filter { MarkerContextTab.of($0.componentType) != nil }
    }

    @ViewBuilder
    private var attachedStrip: some View {
        let drafts = contextDrafts
        if !drafts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("On this marker")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(drafts) { draft in chip(draft) }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func chip(_ draft: MarkerComponentDraft) -> some View {
        let color = MarkerContextTab.of(draft.componentType)?.color ?? AppColors.overlayPanelSecondaryText
        let editable = placementState.workspaceAllows(draft.componentType)
        return HStack(spacing: 0) {
            Button { edit(draft) } label: {
                HStack(spacing: 6) {
                    Image(systemName: draft.componentType.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                    Text(chipTitle(draft))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(chipTitle(draft))")
            .accessibilityIdentifier("workspace.edit.\(draft.id)")
            Button { placementState.removeWorkspaceComponent(draft.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .frame(width: 28, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(chipTitle(draft))")
            .accessibilityIdentifier("workspace.remove.\(draft.id)")
        }
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
        .disabled(!editable)
        .id(draft.id.uuidString)
    }

    // MARK: Tabs

    /// Equal segments, icon over name, so every tab fits on any phone; the
    /// chosen one fills in its arc colour, and a dot counts what is attached.
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(placementState.workspaceContextTabs, id: \.self) { item in
                let isSelected = item == tab
                Button {
                    placementState.workspace.contextTab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    // Tinted with an outline in the family colour: white words
                    // on a bright orange or cyan fill failed contrast.
                    .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 11).fill(isSelected ? item.color.opacity(0.26) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(isSelected ? item.color : Color.clear, lineWidth: 1.5))
                    .overlay(alignment: .topTrailing) {
                        if let count = count(item) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                                .padding(6)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title + (count(item).map { ", \($0) added" } ?? ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("workspace.tab.\(item.rawValue)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15).fill(AppColors.whiteText.opacity(0.06)))
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func count(_ tab: MarkerContextTab) -> Int? {
        let n = contextDrafts.filter { MarkerContextTab.of($0.componentType) == tab }.count
        return n > 0 ? n : nil
    }

    // MARK: Indicators

    private var indicators: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(IndicatorSubTab.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.vertical, 1)
            }
            if !activeChartIndicators.isEmpty {
                copyRow("Use my chart's indicators", count: activeChartIndicators.count) {
                    let result = placementState.attachActiveChartIndicators(activeChartIndicators)
                    placementState.workspace.message = result.blockedByLimit ? placementState.limitMessage(for: .indicatorPanels) : nil
                }
            }
            grid {
                ForEach(IndicatorCatalogItem.all.filter { $0.category == placementState.workspace.indicatorCategory.category }) { item in
                    indicatorCard(item)
                }
            }
        }
    }

    /// The original category tabs as workspace chips: text that scales and
    /// reads on every sheet; the chosen one tinted and outlined in orange.
    private func categoryChip(_ category: IndicatorSubTab) -> some View {
        let isSelected = category == placementState.workspace.indicatorCategory
        let color = MarkerContextTab.indicators.color
        return Button {
            placementState.workspace.indicatorCategory = category
        } label: {
            Label(category.title, systemImage: category.icon)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(Capsule().fill(isSelected ? color.opacity(0.24) : AppColors.whiteText.opacity(0.06)))
                .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1.2))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("workspace.category.\(category.rawValue)")
    }

    private func attachedCount(_ item: IndicatorCatalogItem) -> Int {
        placementState.indicatorDrafts.filter { draft in
            guard case .indicator(let payload) = draft.payload else { return false }
            return payload.name == item.payloadName
        }.count
    }

    private func indicatorCard(_ item: IndicatorCatalogItem) -> some View {
        let attached = attachedCount(item)
        return card(
            icon: item.icon,
            title: item.title,
            // The full name, unless it is the short one again ("MACD").
            detail: item.description == item.title ? nil : item.description,
            tint: MarkerContextTab.indicators.color,
            state: attached == 0 ? .add : .added(attached > 1 ? "×\(attached)" : nil)
        ) {
            placementState.beginWorkspaceIndicator(item)
        }
        .id(item.id)
        .accessibilityIdentifier("workspace.indicator.\(item.id)")
    }

    // MARK: Drawings

    private var drawingTools: [MarkerDrawingToolKind] {
        MarkerDrawingToolKind.allCases.filter { tool in
            guard let type = tool.componentType else { return false }
            return tool.isPhaseOneEnabled && tool.group != .annotation && placementState.workspaceAllows(type)
        }
    }

    private var drawings: some View {
        let tools = drawingTools
        let lines = tools.filter { $0 != .support && $0 != .resistance && $0.group != .pattern }
        let patterns = tools.filter { $0.group == .pattern }
        return VStack(alignment: .leading, spacing: 12) {
            if !activeChartDrawings.isEmpty {
                copyRow("Use my chart's drawings", count: activeChartDrawings.count) {
                    // The attach path enforces the drawing count; filter what
                    // this type can carry before it creates any component.
                    let supported = activeChartDrawings.filter { drawing in
                        let draft = ChartDrawingBridge.markerDraft(from: drawing, anchorTime: placementState.anchorDraft?.payload.anchorTime ?? Date(),
                                                                  anchorPrice: placementState.anchorDraft?.payload.levelPrice ?? 0)
                        return placementState.workspaceAllows(draft.componentType)
                    }
                    let result = placementState.attachActiveChartDrawings(supported)
                    placementState.workspace.message = result.blockedByLimit ? placementState.limitMessage(for: .drawingOverlays) : nil
                }
            }
            if placementState.workspaceAllows(.levelSupport) {
                section("Levels", hint: "Set a price, or drag it on the chart.") {
                    grid {
                        levelCard(.levelSupport, title: "Support", icon: "arrow.down.to.line")
                        levelCard(.levelResistance, title: "Resistance", icon: "arrow.up.to.line")
                    }
                }
            }
            if !lines.isEmpty {
                section("Lines", hint: "Choose a tool, then draw it on the chart.") { grid { ForEach(lines, id: \.self) { toolCard($0) } } }
            }
            if !patterns.isEmpty {
                section("Patterns") { grid { ForEach(patterns, id: \.self) { toolCard($0) } } }
            }
        }
    }

    private func levelCard(_ type: RLComponentType, title: String, icon: String) -> some View {
        card(icon: icon, title: title, detail: nil, tint: MarkerContextTab.drawings.color, state: .add) {
            placementState.beginWorkspaceLevel(type)
        }
        .accessibilityIdentifier("workspace.level.\(type == .levelSupport ? "support" : "resistance")")
    }

    private func toolCard(_ tool: MarkerDrawingToolKind) -> some View {
        card(icon: tool.icon, title: tool.title, detail: nil, tint: MarkerContextTab.drawings.color, state: .go) {
            if placementState.beginWorkspaceDrawing(tool) { onBeginInteractiveDrawing?() }
        }
        .id(tool.rawValue)
        .accessibilityIdentifier("workspace.drawing.\(tool.rawValue)")
    }

    // MARK: Timeframes

    private var timeframes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Link up to two other timeframes this view rests on.")
                .font(.footnote)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
            MarkerTileGrid(columns: dynamicTypeSize.isAccessibilitySize ? 2 : 4, spacing: 8) {
                ForEach(RLChartTimeframe.allCases, id: \.rawValue) { timeframe in
                    timeframeChip(timeframe)
                }
            }
        }
    }

    private func timeframeChip(_ timeframe: RLChartTimeframe) -> some View {
        let value = timeframe.toBackendString()
        let linked = placementState.isTimeframeLinked(value)
        let isChart = timeframe == currentChartTimeframe
        let color = MarkerContextTab.timeframes.color
        return Button {
            guard placementState.workspaceAllows(.timeframeLink), !isChart else { return }
            if linked {
                placementState.removeTimeframeLink(value)
            } else if !placementState.upsertTimeframeLink(value) {
                placementState.workspace.message = placementState.limitMessage(for: .timeframeLinks)
            }
        } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(linked ? .white : AppColors.primaryForeground)
                Text(isChart ? "This chart" : linked ? "Linked" : " ")
                    .font(.caption2)
                    .foregroundColor(linked ? .white.opacity(0.85) : AppColors.overlayPanelSecondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 12).fill(linked ? color : AppColors.whiteText.opacity(isChart ? 0.03 : 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isChart ? color.opacity(0.5) : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isChart)
        .accessibilityLabel("\(timeframe.displayName)\(isChart ? ", this chart" : linked ? ", linked" : "")")
        .accessibilityAddTraits(linked ? .isSelected : [])
        .accessibilityIdentifier("workspace.timeframe.\(value)")
        .id(value)
    }

    // MARK: Notes

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if placementState.workspaceAllows(.textNote) {
                card(icon: "text.bubble", title: "Chart note", detail: "A short note pinned at your marker",
                     tint: MarkerContextTab.notes.color, state: .add, wide: true) {
                    placementState.beginWorkspaceText(.noteEditor)
                }
                .accessibilityIdentifier("workspace.note.add")
            }
            if placementState.workspaceAllows(.linkURL) {
                if let source = placementState.component(.linkURL) {
                    card(icon: "link", title: "Source link", detail: "Edit the article, post or video this is from",
                         tint: MarkerContextTab.timeframes.color, state: .added(nil), wide: true) {
                        placementState.beginWorkspaceText(.sourceEditor, componentID: source.id)
                    }
                    .accessibilityIdentifier("workspace.source.edit")
                } else {
                    card(icon: "link", title: "Source link", detail: "The article, post or video this is from",
                         tint: MarkerContextTab.timeframes.color, state: .add, wide: true) {
                        placementState.beginWorkspaceText(.sourceEditor)
                    }
                    .accessibilityIdentifier("workspace.source.add")
                }
            }
        }
    }

    // MARK: Parts

    private enum CardState { case add, go, added(String?) }

    /// Every tile exists at once (a lazy grid would leave off-screen ones
    /// unbuilt for VoiceOver); one column at accessibility text sizes.
    private func grid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        MarkerTileGrid(columns: dynamicTypeSize.isAccessibilitySize ? 1 : 2, spacing: 10) { content() }
    }

    private func section<Content: View>(_ title: String, hint: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                    .accessibilityAddTraits(.isHeader)
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            content()
        }
    }

    /// A tile: the tool's icon in its family colour, its name and what it is,
    /// and whether it is on the marker already.
    private func card(icon: String, title: String, detail: String?, tint: Color, state: CardState,
                      wide: Bool = false, action: @escaping () -> Void) -> some View {
        let added: Bool = { if case .added = state { return true }; return false }()
        let iconView = Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 32, height: 32)
            .background(Circle().fill(tint.opacity(0.16)))
            .accessibilityHidden(true)
        let words = VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        return Button(action: action) {
            Group {
                if wide {
                    // A full-width row: icon, words, badge.
                    HStack(alignment: .center, spacing: 10) {
                        iconView
                        words
                        Spacer(minLength: 0)
                        stateBadge(state, tint: tint)
                    }
                } else {
                    // A tile: icon and badge on top, the name across the tile.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            iconView
                            Spacer(minLength: 0)
                            stateBadge(state, tint: tint)
                        }
                        words
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: wide ? 56 : 64, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.whiteText.opacity(added ? 0.09 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(added ? tint.opacity(0.6) : AppColors.whiteText.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(added ? "Added" : "")
    }

    @ViewBuilder
    private func stateBadge(_ state: CardState, tint: Color) -> some View {
        switch state {
        case .add:
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .accessibilityHidden(true)
        case .go:
            Image(systemName: "hand.draw")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .accessibilityHidden(true)
        case .added(let count):
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                if let count { Text(count).font(.caption2.weight(.bold)) }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(tint))
            .accessibilityHidden(true)
        }
    }

    private func copyRow(_ title: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("\(title) (\(count))", systemImage: "square.on.square")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.copy.\(title)")
    }

    // MARK: Editing what is attached

    private func edit(_ draft: MarkerComponentDraft) {
        switch draft.payload {
        case .indicator(let payload):
            if let item = IndicatorCatalogItem.item(forIndicatorName: payload.name) {
                placementState.beginWorkspaceIndicator(item, draftID: draft.id)
            }
        case .link: placementState.beginWorkspaceText(.sourceEditor, componentID: draft.id)
        case .note: placementState.beginWorkspaceText(.noteEditor, componentID: draft.id)
        case .timeframeLink: placementState.workspace.contextTab = .timeframes
        case .levelSupport, .levelResistance: placementState.beginWorkspaceLevel(draft.componentType, componentID: draft.id)
        default:
            let tool: MarkerDrawingToolKind? = {
                if case .drawingPattern(let payload) = draft.payload { return MarkerDrawingToolKind.from(patternKey: payload.patternKey) }
                return MarkerDrawingToolKind.from(componentType: draft.componentType)
            }()
            if let tool, placementState.beginWorkspaceDrawing(tool, componentID: draft.id) { onBeginInteractiveDrawing?() }
        }
    }

    /// "RSI 14", "Support 63,780.00", "4h", "Note: Range low…".
    private func chipTitle(_ draft: MarkerComponentDraft) -> String {
        switch draft.payload {
        case .indicator(let payload):
            if let period = payload.settings?["period"]?.value {
                return "\(payload.name) \(period)"
            }
            return payload.name
        case .timeframeLink(let payload): return payload.timeframe
        case .link(let payload): return payload.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Source"
        case .note(let payload):
            let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.count > 18 ? "Note: \(text.prefix(18))…" : "Note: \(text)"
        case .levelSupport, .levelResistance:
            return "\(draft.componentType.displayName) \(MarkerGuidedFormat.displayPrice(draft.payload.levelPrice))"
        default: return draft.componentType.displayName
        }
    }
}

/// Equal columns, rows as tall as their tallest tile, every tile laid out.
struct MarkerTileGrid: Layout {
    var columns: Int
    var spacing: CGFloat

    private func columnWidth(_ width: CGFloat) -> CGFloat {
        max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func rowHeights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
                .max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = rowHeights(subviews, width: columnWidth(width))
        let height = heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = columnWidth(bounds.width)
        let heights = rowHeights(subviews, width: width)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (width + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + spacing
        }
    }
}
