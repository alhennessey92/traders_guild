//
//  MarkerCreationSheet.swift
//  traders_guild
//
//  Created by Al Hennessey on 17/12/2025.
//

//
//  MarkerCreationSheet.swift
//  traders_guild
//
//  Marker creation sheet for configuring new markers before placement
//  Works with ChartMarkerUI

import SwiftUI

// MARK: - Marker Creation Sheet

struct MarkerCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let username: String
    let chartData: ChartDataManager
    let candles: [RLCandleDTO]
    let markerType: RLMarkerType
    let initialTargetPrice: Double?
    let initialHorizontalLinePrice: Double?
    let initialStopLossPrice: Double?
    @Binding var placementAlertSeverity: MarkerAlertSeverity?
    @Binding var placementSelectedEmoji: String?
    
    @State private var note: String = ""
    
    // Type-specific state
    @State private var alertSeverity: MarkerAlertSeverity = .moderate
    @State private var trendlineDirection: TrendlineDirection = .up
    @State private var selectedIndicator: String = "RSI"
    @State private var chartPattern: ChartPattern = .doubleTop
    @State private var selectedEmoji: String = "🎯"
    @State private var pollQuestion: String = ""
    @State private var pollOption1: String = ""
    @State private var pollOption2: String = ""
    @State private var questionText: String = ""
    @State private var targetPrice: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            headerView
            
            Divider()
            
            // Form Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Context Info Card
                    contextInfoCard
                    
                    // Type-specific options
                    typeSpecificOptionsView
                    
                    // Note Section
                    noteSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            
            Divider()
            
            // Action Buttons
            actionButtons
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .interactiveDismissDisabled(true)
        .onAppear {
            // Initialize target price for prediction markers
            if let initialTarget = initialTargetPrice {
                targetPrice = chartData.formatPrice(initialTarget)
            }
            if markerType == .alert { placementAlertSeverity = alertSeverity }
            if markerType == .emoji { placementSelectedEmoji = selectedEmoji }
        }
        .onChange(of: alertSeverity) { _, new in
            if markerType == .alert { placementAlertSeverity = new }
        }
        .onChange(of: selectedEmoji) { _, new in
            if markerType == .emoji { placementSelectedEmoji = new }
        }
    }
    
    // MARK: - Header
    
    private var headerColor: Color {
        if markerType == .alert { return alertSeverity.color }
        return markerType.color
    }

    private var headerView: some View {
        HStack(spacing: 15) {
            // Marker Icon (emoji type shows chosen emoji; alert uses severity color)
            ZStack {
                Circle()
                    .fill(headerColor.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if markerType == .emoji {
                    Text(selectedEmoji)
                        .font(.system(size: 28))
                } else {
                    Image(systemName: markerType.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(headerColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Add \(markerType.rawValue)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text("Configure marker details")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Context Info Card
    
    private var contextInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Marker Context")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Time")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                }
                
                HStack {
                    Text("Price")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                }
                
                if markerType == .predictionTarget, let target = initialTargetPrice {
                    HStack {
                        Text("Take Profit")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(chartData.formatPrice(target))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                if markerType == .predictionTarget, let sl = initialStopLossPrice {
                    HStack {
                        Text("Stop Loss")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(chartData.formatPrice(sl))
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Type-Specific Options
    
    @ViewBuilder
    private var typeSpecificOptionsView: some View {
        switch markerType {
        case .alert:
            alertSeverityPicker
        case .trendline:
            trendlineDirectionPicker
        case .indicator:
            indicatorPicker
        case .pattern:
            patternPicker
        case .emoji:
            emojiPicker
        case .poll:
            pollOptionsSection
        case .question:
            questionSection
        case .predictionTarget:
            predictionTradeDetailsSection
        default:
            EmptyView()
        }
    }

    private var predictionTradeDetailsSection: some View {
        let entryVal = price
        let targetVal: Double? = initialTargetPrice ?? Double(targetPrice.replacingOccurrences(of: ",", with: ""))
        let slVal: Double? = initialStopLossPrice
        let isLong = (targetVal ?? entryVal) > entryVal
        let rrRatio: String? = {
            guard let t = targetVal else { return nil }
            let reward = abs(t - entryVal)
            let risk: Double
            if let sl = slVal {
                risk = abs(sl - entryVal)
            } else {
                risk = entryVal * 0.01
            }
            guard risk > 0 else { return "—" }
            return String(format: "%.2f", reward / risk)
        }()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Trade details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                Text(isLong ? "LONG" : "SHORT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isLong ? .green : .red)
            }
            VStack(spacing: 8) {
                HStack {
                    Text("Entry")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(chartData.formatPrice(entryVal))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                if let t = targetVal {
                    HStack {
                        Text("Take Profit")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(chartData.formatPrice(t))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                if let sl = slVal {
                    HStack {
                        Text("Stop Loss")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(chartData.formatPrice(sl))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
                if let rr = rrRatio {
                    HStack {
                        Text("R:R")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(rr)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                    }
                }
            }
            .padding(12)
            .background(AppColors.whiteText.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Question (required)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            TextField("Enter your question...", text: $questionText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(12)
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(8)
                .foregroundColor(AppColors.whiteText)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var alertSeverityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Alert Severity")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            Picker("Severity", selection: $alertSeverity) {
                ForEach(MarkerAlertSeverity.allCases, id: \.self) { severity in
                    HStack {
                        Circle().fill(severity.color).frame(width: 8, height: 8)
                        Text(severity.rawValue)
                    }
                    .tag(severity)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var trendlineDirectionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Trend Direction")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            Picker("Direction", selection: $trendlineDirection) {
                ForEach(TrendlineDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var indicatorPicker: some View {
        let indicators = ["RSI", "MACD", "Stochastic", "Moving Average", "Bollinger Bands", "Volume"]
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Indicator")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(indicators, id: \.self) { indicator in
                    Button(action: { selectedIndicator = indicator }) {
                        Text(indicator)
                            .font(.subheadline)
                            .fontWeight(selectedIndicator == indicator ? .semibold : .regular)
                            .foregroundColor(selectedIndicator == indicator ? .white : AppColors.greyText)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIndicator == indicator ? AppColors.accentColor : AppColors.whiteText.opacity(0.05))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var patternPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Chart Pattern")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ChartPattern.allCases, id: \.self) { pattern in
                    Button(action: { chartPattern = pattern }) {
                        Text(pattern.rawValue)
                            .font(.caption)
                            .fontWeight(chartPattern == pattern ? .semibold : .regular)
                            .foregroundColor(chartPattern == pattern ? .white : AppColors.greyText)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(chartPattern == pattern ? AppColors.accentColor : AppColors.whiteText.opacity(0.05))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var emojiPicker: some View {
        let emojis = ["🎯", "🚀", "📈", "📉", "💰", "⚠️", "🔥", "💎", "🐂", "🐻", "👀", "🤔"]
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "face.smiling")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Select Emoji")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { selectedEmoji = emoji }) {
                        Text(emoji)
                            .font(.title)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? AppColors.accentColor.opacity(0.3) : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(selectedEmoji == emoji ? AppColors.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var pollOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Create Poll")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            TextField("Poll question", text: $pollQuestion)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(8)
                .foregroundColor(AppColors.whiteText)
            
            TextField("Option 1", text: $pollOption1)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(8)
                .foregroundColor(AppColors.whiteText)
            
            TextField("Option 2", text: $pollOption2)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(8)
                .foregroundColor(AppColors.whiteText)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Note Section
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Add Note (Optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            TextField("Your analysis or comment...", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(12)
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(8)
                .foregroundColor(AppColors.whiteText)
        }
        .padding(16)
        .background(AppColors.whiteText.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var buttonBackgroundColor: Color {
        if markerType == .predictionTarget { return Color.blue.opacity(0.9) }
        if markerType == .emoji { return Color.gray.opacity(0.5) }
        return markerType.color.opacity(0.9)
    }
    private var buttonForegroundColor: Color {
        if markerType == .predictionTarget { return .white }
        if markerType == .emoji { return .white }
        return canPlaceMarker ? .white : .white.opacity(0.6)
    }

    /// Poll requires question and 2 options; Question type requires question text.
    private var canPlaceMarker: Bool {
        switch markerType {
        case .poll:
            return !pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !pollOption1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !pollOption2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .question:
            return !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Cancel Button
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.whiteText.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Add Marker Button (disabled for Poll/Question until valid; emoji uses non-white background)
            Button(action: addMarker) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Marker")
                }
                .font(.headline)
                .foregroundColor(buttonForegroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canPlaceMarker ? buttonBackgroundColor : buttonBackgroundColor.opacity(0.5))
                .cornerRadius(12)
            }
            .disabled(!canPlaceMarker)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Add Marker Action
    
    private func addMarker() {
        // Get the symbol ID from current chart context
        guard let symbolId = chartData.currentSymbol?.id else {
            return
        }
        
        // Build poll options if this is a poll marker
        var pollOptionsList: [String]? = nil
        if markerType == .poll && !pollQuestion.isEmpty {
            pollOptionsList = []
            if !pollOption1.isEmpty {
                pollOptionsList?.append(pollOption1)
            }
            if !pollOption2.isEmpty {
                pollOptionsList?.append(pollOption2)
            }
        }
        
        // Parse target price for prediction markers
        var targetPriceValue: Double? = nil
        if markerType == .predictionTarget {
            targetPriceValue = initialTargetPrice ?? Double(targetPrice.replacingOccurrences(of: ",", with: ""))
        }
        
        let effectiveNote: String?
        if markerType == .question {
            effectiveNote = questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (note.isEmpty ? nil : note) : questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            effectiveNote = note.isEmpty ? nil : note
        }

        Task {
            let success = await markerManager.addMarker(
                symbolId: symbolId,
                candleIndex: candleIndex,
                timestamp: timestamp,
                price: price,
                type: markerType,
                note: effectiveNote,
                candles: candles,
                horizontalLinePrice: initialHorizontalLinePrice,
                targetPrice: targetPriceValue,
                stopLossPrice: initialStopLossPrice,
                alertSeverity: markerType == .alert ? alertSeverity : nil,
                trendlineDirection: markerType == .trendline ? trendlineDirection : nil,
                selectedIndicator: markerType == .indicator ? selectedIndicator : nil,
                chartPattern: markerType == .pattern ? chartPattern : nil,
                selectedEmoji: markerType == .emoji ? selectedEmoji : nil,
                pollQuestion: markerType == .poll ? pollQuestion : nil,
                pollOptions: pollOptionsList
            )
            
            if success {
                HapticFeedback.success.trigger()
                dismiss()
            } else {
                HapticFeedback.error.trigger()
            }
        }
    }
}

// MARK: - Marker View (Chart Overlay)

private struct WiggleKeyframe {
    var rotation: Double = 0
    var scaleBoost: Double = 0
}

struct MarkerView: View {
    let marker: ChartMarkerUI
    let isSelected: Bool
    let hideUsername: Bool
    let onTap: () -> Void

    private let markerSize: CGFloat = 32
    @State private var wiggleTrigger: Bool = false

    var body: some View {
        Button(action: {
            onTap()
            wiggleTrigger.toggle()
        }) {
            UnifiedMarkerBadge(
                type: marker.type,
                displayColor: marker.displayColor,
                size: markerSize,
                emoji: marker.type == .emoji ? marker.selectedEmoji : nil,
                isSelected: isSelected
            )
            .keyframeAnimator(initialValue: WiggleKeyframe(), trigger: wiggleTrigger) { content, value in
                content
                    .rotationEffect(.degrees(value.rotation))
                    .scaleEffect(1.0 + value.scaleBoost)
            } keyframes: { _ in
                KeyframeTrack(\.rotation) {
                    SpringKeyframe(8, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(-6, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(4, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(-2, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(0, duration: 0.18, spring: .smooth)
                }
                KeyframeTrack(\.scaleBoost) {
                    SpringKeyframe(0.12, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(0, duration: 0.4, spring: .smooth)
                }
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Marker Settings View

struct MarkerSettingsView: View {
    @ObservedObject var settings = MarkerDisplaySettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Marker Distance")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Distance from Candle")
                            Spacer()
                            Text("\(Int(settings.baseOffset)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(value: $settings.baseOffset, in: 40...120, step: 5)
                            .tint(.cyan)
                        
                        Text("How far markers appear from candle high/low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Stack Spacing")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Space Between Stacked Markers")
                            Spacer()
                            Text("\(Int(settings.stackOffset)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(value: $settings.stackOffset, in: 34...60, step: 2)
                            .tint(.cyan)
                        
                        Text("Vertical spacing when multiple markers on same candle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Stack Spacing")
                            Spacer()
                            Text("\(Int(settings.minStackSpacing)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(value: $settings.minStackSpacing, in: 32...50, step: 2)
                            .tint(.orange)
                        
                        Text("Prevents overlap when chart is zoomed out vertically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(action: { settings.resetToDefaults() }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Marker Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Marker Settings Button

struct MarkerSettingsButton: View {
    @State private var showSettings = false
    
    var body: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .sheet(isPresented: $showSettings) {
            MarkerSettingsView()
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Marker Placement Price Indicator

struct MarkerPlacementPriceIndicator: View {
    let price: Double
    let markerType: RLMarkerType
    let priceScale: CGFloat
    let verticalOffset: CGFloat
    let chartHeight: CGFloat
    let priceRange: (min: Double, max: Double)
    let chartData: ChartDataManager
    
    private var indicatorYPosition: CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    private var isVisible: Bool {
        indicatorYPosition >= 0 && indicatorYPosition <= chartHeight
    }
    
    private var formattedPrice: String {
        chartData.formatPrice(price)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible && price > 0 {
                Canvas { context, size in
                    let y = indicatorYPosition
                    let lineEndX = size.width - 60
                    
                    let linePath = Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: lineEndX, y: y))
                    }
                    context.stroke(
                        linePath,
                        with: .color(markerType.color.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
                    
                    let labelX = size.width - 35
                    let labelRect = CGRect(x: labelX - 35, y: y - 11, width: 70, height: 22)
                    let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
                    context.fill(roundedPath, with: .color(markerType.color))
                    
                    let text = Text(formattedPrice)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    context.draw(text, at: CGPoint(x: labelX, y: y))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
