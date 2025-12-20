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
//  Works with ChartMarkerDTO

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
    let candles: [CandleDTO]
    let markerType: MarkerType
    let initialTargetPrice: Double?
    
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
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 15) {
            // Marker Icon
            ZStack {
                Circle()
                    .fill(markerType.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: markerType.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(markerType.color)
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
                        Text("Target")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                        Spacer()
                        Text(chartData.formatPrice(target))
                            .font(.subheadline)
                            .foregroundColor(.orange)
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
        default:
            EmptyView()
        }
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
            
            // Add Marker Button
            Button(action: addMarker) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Marker")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(markerType.color)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Add Marker Action
    
    private func addMarker() {
        // Get the symbol ID from current symbol or use a default
        let symbolId = chartData.currentSymbol?.id ?? UUID()
        
        // Build poll options if this is a poll marker
        var pollOptionsDTO: [PollOptionDTO]? = nil
        if markerType == .poll && !pollQuestion.isEmpty {
            pollOptionsDTO = []
            if !pollOption1.isEmpty {
                pollOptionsDTO?.append(PollOptionDTO(id: UUID(), text: pollOption1, voteCount: 0, hasVoted: false))
            }
            if !pollOption2.isEmpty {
                pollOptionsDTO?.append(PollOptionDTO(id: UUID(), text: pollOption2, voteCount: 0, hasVoted: false))
            }
        }
        
        // Parse target price for prediction markers
        var targetPriceValue: Double? = nil
        if markerType == .predictionTarget {
            targetPriceValue = initialTargetPrice ?? Double(targetPrice.replacingOccurrences(of: ",", with: ""))
        }
        
        let success = markerManager.addMarker(
            symbolId: symbolId,
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: markerType,
            note: note.isEmpty ? nil : note,
            candles: candles,
            horizontalLinePrice: nil,
            targetPrice: targetPriceValue,
            alertSeverity: markerType == .alert ? alertSeverity : nil,
            trendlineDirection: markerType == .trendline ? trendlineDirection : nil,
            selectedIndicator: markerType == .indicator ? selectedIndicator : nil,
            chartPattern: markerType == .pattern ? chartPattern : nil,
            selectedEmoji: markerType == .emoji ? selectedEmoji : nil,
            pollQuestion: markerType == .poll ? pollQuestion : nil,
            pollOptions: pollOptionsDTO
        )
        
        if success {
            HapticFeedback.success.trigger()
            dismiss()
        } else {
            HapticFeedback.error.trigger()
        }
    }
}

// MARK: - Marker View (Chart Overlay)

struct MarkerView: View {
    let marker: ChartMarkerDTO
    let isSelected: Bool
    let hideUsername: Bool
    let onTap: () -> Void
    
    private let markerSize: CGFloat = 32
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if !marker.positionedBelow && !hideUsername {
                    usernameLabel
                }
                
                markerIcon
                
                if marker.positionedBelow && !hideUsername {
                    usernameLabel
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var markerIcon: some View {
        ZStack {
            Circle()
                .fill(marker.type.color.opacity(0.2))
                .frame(width: markerSize, height: markerSize)
            
            Circle()
                .stroke(marker.type.color, lineWidth: isSelected ? 3 : 2)
                .frame(width: markerSize, height: markerSize)
            
            Image(systemName: marker.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(marker.type.color)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
    
    private var usernameLabel: some View {
        Text(marker.author.globalMember.username)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(1)
            .frame(maxWidth: 60)
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
    let markerType: MarkerType
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
