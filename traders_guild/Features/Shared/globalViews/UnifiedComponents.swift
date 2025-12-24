//
//  UnifiedComponents.swift
//  traders_guild
//
//  Unified UI Components for consistent styling across the app
//  Includes: Disclosure Groups, Search Bars, Tab Bars, Section Headers
//
//  Usage: Import this file and use these components for visual consistency
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - UNIFIED DISCLOSURE GROUP
// MARK: - ================================================================================================

/// Unified collapsible disclosure group with consistent styling
/// Use for: Asset classes, chatrooms, user groups, any expandable list section
struct UnifiedDisclosureGroup<Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    var isExpandedByDefault: Bool = true
    @ViewBuilder let content: () -> Content
    
    @State private var isExpanded: Bool = true
    
    init(
        title: String,
        count: Int,
        icon: String,
        iconColor: Color,
        isExpandedByDefault: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self.icon = icon
        self.iconColor = iconColor
        self.isExpandedByDefault = isExpandedByDefault
        self.content = content
        self._isExpanded = State(initialValue: isExpandedByDefault)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 18)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            if isExpanded {
                content()
            }
        }
    }
}

/// Variant with custom header content (e.g., for adding badges, icons, etc.)
struct UnifiedDisclosureGroupCustomHeader<Header: View, Content: View>: View {
    var isExpandedByDefault: Bool = true
    @ViewBuilder let header: (Bool) -> Header  // Pass isExpanded state
    @ViewBuilder let content: () -> Content
    
    @State private var isExpanded: Bool = true
    
    init(
        isExpandedByDefault: Bool = true,
        @ViewBuilder header: @escaping (Bool) -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isExpandedByDefault = isExpandedByDefault
        self.header = header
        self.content = content
        self._isExpanded = State(initialValue: isExpandedByDefault)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                header(isExpanded)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                content()
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED SEARCH BAR
// MARK: - ================================================================================================

/// Unified search bar with consistent capsule styling
/// Use for: Symbol search, user search, chatroom search, any text search input
struct UnifiedSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onTextChange: ((String) -> Void)? = nil
    var onClear: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 15))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    onTextChange?(newValue)
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .onTapGesture {
            isFocused = true
        }
    }
}

/// Search bar variant with autocapitalization for symbols
struct UnifiedSymbolSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search symbols..."
    var onTextChange: ((String) -> Void)? = nil
    var onClear: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 15))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .submitLabel(.done)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    onTextChange?(newValue)
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .onTapGesture {
            isFocused = true
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED TAB COMPONENTS
// MARK: - ================================================================================================

/// Protocol for tab items with icon and label
protocol UnifiedTabItem: Hashable, CaseIterable {
    var title: String { get }
    var icon: String { get }
}

/// Size variants for tab buttons
enum UnifiedTabSize {
    case compact     // Icon only when unselected, icon + label when selected
    case standard    // Always shows icon + label
    case iconOnly    // Always icon only
    
    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 12
        case .standard: return 14
        case .iconOnly: return 10
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .standard: return 10
        case .iconOnly: return 10
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .compact: return 11
        case .standard: return 12
        case .iconOnly: return 14
        }
    }
    
    var labelSize: CGFloat {
        switch self {
        case .compact: return 11
        case .standard: return 13
        case .iconOnly: return 11
        }
    }
}

/// Color theme for tabs
enum UnifiedTabTheme {
    case blue           // Default blue accent
    case colored        // Per-tab colors (personal=yellow, guild=blue, etc.)
    case accent         // Uses AppColors.accentColor
    
    // Consistent blue gradient used across all tab types
    static var consistentBlueGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.4, blue: 0.8),      // #3366CC
                Color(red: 0.15, green: 0.25, blue: 0.5)    // #263F80
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    func selectedBackground(for index: Int) -> LinearGradient {
        switch self {
        case .blue:
            return UnifiedTabTheme.consistentBlueGradient
        case .colored:
            let colors: [(Color, Color)] = [
                (.yellow.opacity(0.5), .orange.opacity(0.3)),
                (.blue.opacity(0.5), .purple.opacity(0.3)),
                (.green.opacity(0.5), .teal.opacity(0.3)),
                (.pink.opacity(0.5), .red.opacity(0.3))
            ]
            let colorPair = colors[index % colors.count]
            return LinearGradient(
                colors: [colorPair.0, colorPair.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accent:
            return LinearGradient(
                colors: [AppColors.accentColor.opacity(0.7), AppColors.accentColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    func borderColor(for index: Int) -> Color {
        switch self {
        case .blue:
            return Color.blue.opacity(0.4)
        case .colored:
            let colors: [Color] = [.yellow, .blue, .green, .pink]
            return colors[index % colors.count].opacity(0.3)
        case .accent:
            return AppColors.accentColor.opacity(0.4)
        }
    }
}

/// Unified tab button with consistent capsule styling
struct UnifiedTabButton<Tab: UnifiedTabItem>: View {
    let tab: Tab
    let isSelected: Bool
    let size: UnifiedTabSize
    let theme: UnifiedTabTheme
    let index: Int
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                
                // Show label based on size variant
                if size == .standard || (size == .compact && isSelected) {
                    Text(tab.title)
                        .font(.system(size: size.labelSize, weight: .medium))
                }
                
                // Optional count badge
                if let count = count {
                    Text("(\(count))")
                        .font(.system(size: size.labelSize - 2))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .gray)
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, isSelected ? size.horizontalPadding : size.horizontalPadding - 2)
            .padding(.vertical, size.verticalPadding)
            .background(
                isSelected ?
                theme.selectedBackground(for: index) :
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.borderColor(for: index) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Unified tab bar container
struct UnifiedTabBar<Tab: UnifiedTabItem>: View where Tab.AllCases: RandomAccessCollection {
    @Binding var selectedTab: Tab
    var size: UnifiedTabSize = .standard
    var theme: UnifiedTabTheme = .blue
    var countForTab: ((Tab) -> Int)? = nil
    var spacing: CGFloat = 6
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                UnifiedTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    size: size,
                    theme: theme,
                    index: index,
                    count: countForTab?(tab)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED CATEGORY TABS (for Indicators, etc.)
// MARK: - ================================================================================================

/// Category tab button with icon + label horizontal (capsule shape for consistency)
/// Compact design to fit all tabs on one line (Trend, Volatility, Momentum, Volume)
struct UnifiedCategoryTabButton<Tab: UnifiedTabItem>: View {
    let tab: Tab
    let isSelected: Bool
    let index: Int
    var theme: UnifiedTabTheme = .blue
    let action: () -> Void
    
    // Consistent blue gradient for all category tabs
    private var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.4, blue: 0.8),      // #3366CC
                Color(red: 0.15, green: 0.25, blue: 0.5)    // #263F80
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var unselectedGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Shortened title for compact display
    private var compactTitle: String {
        let title = tab.title
        // Shorten long titles
        switch title.lowercased() {
        case "volatility": return "Volat."
        case "momentum": return "Mom."
        default: return title
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(compactTitle)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? selectedGradient : unselectedGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Category tab bar (horizontal, scrollable if needed)
struct UnifiedCategoryTabBar<Tab: UnifiedTabItem>: View where Tab.AllCases: RandomAccessCollection {
    @Binding var selectedTab: Tab
    var theme: UnifiedTabTheme = .blue
    var spacing: CGFloat = 6
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                    UnifiedCategoryTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        index: index,
                        theme: theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED INDICATOR ADD BUTTON (Rectangular, Bigger)
// MARK: - ================================================================================================

/// Rectangular add button for indicators (EMA, SMA, etc.)
/// Distinct from capsule tabs to avoid visual confusion
struct UnifiedIndicatorAddButton: View {
    let title: String
    let color: Color
    var icon: String = "plus.circle.fill"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Row of indicator add buttons with consistent spacing
struct UnifiedIndicatorAddButtonRow: View {
    let buttons: [(title: String, color: Color, action: () -> Void)]
    var spacing: CGFloat = 10
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(buttons.indices, id: \.self) { index in
                UnifiedIndicatorAddButton(
                    title: buttons[index].title,
                    color: buttons[index].color,
                    action: buttons[index].action
                )
            }
            Spacer()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED SECTION HEADER
// MARK: - ================================================================================================

/// Unified section header with optional action button
struct UnifiedSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentColor)
                }
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED EMPTY STATE
// MARK: - ================================================================================================

/// Unified empty state view for lists
struct UnifiedEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color = .gray.opacity(0.4)
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Unified no results state for search
struct UnifiedNoResultsState: View {
    var searchText: String = ""
    var message: String = "No results found"
    var suggestion: String = "Try a different search term"
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.3))
            
            Text(searchText.isEmpty ? message : "No results for '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
            
            Text(suggestion)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED LOADING STATE
// MARK: - ================================================================================================

/// Unified loading state view
struct UnifiedLoadingState: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - ================================================================================================
// MARK: - ASSET CLASS HELPERS
// MARK: - ================================================================================================

/// Get color for asset class (unified across the app)
func assetClassColor(_ assetClass: AssetClass) -> Color {
    switch assetClass {
    case .forex: return .blue
    case .crypto: return .orange
    case .stocks: return .green
    case .commodities: return .yellow
    case .indices: return .purple
    case .futures: return .cyan
    }
}

// MARK: - ================================================================================================
// MARK: - PREVIEW HELPERS
// MARK: - ================================================================================================

#if DEBUG
// Sample tab enum for previews
enum PreviewTab: String, CaseIterable, UnifiedTabItem {
    case personal = "Personal"
    case guild = "Guild"
    case search = "Search"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .personal: return "star.fill"
        case .guild: return "person.3.fill"
        case .search: return "magnifyingglass"
        }
    }
}

enum PreviewCategoryTab: String, CaseIterable, UnifiedTabItem {
    case trend = "Trend"
    case volatility = "Volatility"
    case momentum = "Momentum"
    case volume = "Volume"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .volatility: return "waveform.path.ecg"
        case .momentum: return "gauge.with.dots.needle.33percent"
        case .volume: return "chart.bar.fill"
        }
    }
}

#Preview("Unified Components") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 24) {
                // Search Bar
                UnifiedSearchBar(
                    text: .constant(""),
                    placeholder: "Search chatrooms & users..."
                )
                
                // Tab Bar - Standard
                Text("Standard Tabs").foregroundColor(.gray).font(.caption)
                UnifiedTabBar(
                    selectedTab: .constant(PreviewTab.personal),
                    size: .standard,
                    theme: .colored
                ) { tab in
                    switch tab {
                    case .personal: return 5
                    case .guild: return 12
                    case .search: return 0
                    }
                }
                
                // Tab Bar - Compact
                Text("Compact Tabs").foregroundColor(.gray).font(.caption)
                UnifiedTabBar(
                    selectedTab: .constant(PreviewTab.guild),
                    size: .compact,
                    theme: .blue
                )
                
                // Category Tabs
                Text("Category Tabs").foregroundColor(.gray).font(.caption)
                UnifiedCategoryTabBar(
                    selectedTab: .constant(PreviewCategoryTab.trend),
                    theme: .blue
                )
                
                // Disclosure Group
                Text("Disclosure Group").foregroundColor(.gray).font(.caption)
                UnifiedDisclosureGroup(
                    title: "Forex",
                    count: 8,
                    icon: "dollarsign.circle.fill",
                    iconColor: .blue
                ) {
                    VStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            HStack {
                                Text("EUR/USD")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("1.0850")
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
                
                // Empty State
                UnifiedEmptyState(
                    icon: "star",
                    title: "No Symbols",
                    subtitle: "Search above to add symbols"
                )
                
                // Section Header
                UnifiedSectionHeader(
                    title: "Watchlists",
                    subtitle: "Your saved symbols",
                    actionTitle: "See All"
                ) {
                    print("See all tapped")
                }
            }
            .padding()
        }
    }
}
#endif
