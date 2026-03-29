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
                        .foregroundColor(AppColors.surfaceWhite50)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite50)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
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
                .foregroundColor(AppColors.surfaceWhite50)
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
                        .foregroundColor(AppColors.surfaceWhite50)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
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
                .foregroundColor(AppColors.surfaceWhite50)
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
                        .foregroundColor(AppColors.surfaceWhite50)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
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
    case compact     // Always icon + label with compact spacing
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
        case .standard: return 12
        case .iconOnly: return 12
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
    case subTab         // Level 2: darker navy
    case deepSubTab     // Level 3: darkest navy
    case colored        // Per-tab colors (personal=yellow, guild=blue, etc.)
    case accent         // Uses AppColors.accentColor
    case componentsTabs  // Orange only for "Active" tab (index 0), blue for rest
    case markerNavigation // Live Feed orange, Setups green, grouped/archive blue
    case markerPrimary   // Green for "Add" (index 0), blue for rest

    // Consistent blue gradient used for active/selected tabs
    static var consistentBlueGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.chartTabGradientStart,      // #3366CC
                AppColors.chartTabGradientEnd    // #263F80
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var orangeGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.chartOrangeGradientStart, AppColors.chartOrangeGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var greenGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.chartGreenGradientStart, AppColors.chartGreenGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum MarkerAccent: Equatable {
        case blue
        case orange
        case green
    }

    func markerAccent(forTitle title: String) -> MarkerAccent {
        switch self {
        case .markerNavigation:
            switch title.lowercased() {
            case "live feed":
                return .orange
            case "setups":
                return .green
            default:
                return .blue
            }
        default:
            return .blue
        }
    }

    func selectedBackground<Tab: UnifiedTabItem>(for tab: Tab, index: Int) -> LinearGradient {
        switch self {
        case .blue:
            return UnifiedTabTheme.consistentBlueGradient
        case .subTab:
            return LinearGradient(
                colors: [AppColors.chartSubTabGradientStart, AppColors.chartSubTabGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .deepSubTab:
            return LinearGradient(
                colors: [AppColors.chartDeepSubTabGradientStart, AppColors.chartDeepSubTabGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colored:
            let colors: [(Color, Color)] = [
                (AppColors.statusHighlight50, AppColors.statusWarning30),
                (AppColors.statusInfo50, AppColors.statusSecondary30),
                (AppColors.statusPositive50, AppColors.statusTeal30),
                (AppColors.statusPink50, AppColors.statusNegative30)
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
        case .componentsTabs:
            // Only "Active" tab (index 0) is orange, all others are blue
            return index == 0 ? UnifiedTabTheme.orangeGradient : UnifiedTabTheme.consistentBlueGradient
        case .markerNavigation:
            switch markerAccent(forTitle: tab.title) {
            case .blue:
                return UnifiedTabTheme.consistentBlueGradient
            case .orange:
                return UnifiedTabTheme.orangeGradient
            case .green:
                return UnifiedTabTheme.greenGradient
            }
        case .markerPrimary:
            // "Add" (index 0) = green, all others = blue
            if index == 0 { return UnifiedTabTheme.greenGradient }
            return UnifiedTabTheme.consistentBlueGradient
        }
    }

    func borderColor<Tab: UnifiedTabItem>(for tab: Tab, index: Int) -> Color {
        switch self {
        case .blue:
            return AppColors.statusInfo40
        case .subTab:
            return AppColors.statusInfo40
        case .deepSubTab:
            return AppColors.statusInfo40
        case .colored:
            let colors: [Color] = [.yellow, .blue, .green, .pink]
            return colors[index % colors.count].opacity(0.3)
        case .accent:
            return AppColors.accentColor.opacity(0.4)
        case .componentsTabs:
            return index == 0 ? Color.orange.opacity(0.4) : AppColors.statusInfo40
        case .markerNavigation:
            switch markerAccent(forTitle: tab.title) {
            case .blue:
                return AppColors.statusInfo40
            case .orange:
                return Color.orange.opacity(0.4)
            case .green:
                return AppColors.statusPositive40
            }
        case .markerPrimary:
            if index == 0 { return AppColors.statusPositive40 }
            return AppColors.statusInfo40
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
                if size != .iconOnly {
                    Text(tab.title)
                        .font(.system(size: size.labelSize, weight: .medium))
                }
                
                // Optional count badge
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.system(size: size.labelSize - 2))
                        .foregroundColor(isSelected ? AppColors.surfaceWhite70 : .gray)
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, isSelected ? size.horizontalPadding : size.horizontalPadding - 2)
            .padding(.vertical, size.verticalPadding)
            .background(
                isSelected ?
                theme.selectedBackground(for: tab, index: index) :
                LinearGradient(
                    colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.borderColor(for: tab, index: index) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Unified tab bar container — horizontally scrollable so tab text never wraps
struct UnifiedTabBar<Tab: UnifiedTabItem>: View where Tab.AllCases: RandomAccessCollection {
    @Binding var selectedTab: Tab
    var tabs: [Tab]? = nil
    var size: UnifiedTabSize = .standard
    var theme: UnifiedTabTheme = .blue
    var countForTab: ((Tab) -> Int)? = nil
    var spacing: CGFloat = 6

    var body: some View {
        let resolvedTabs = tabs ?? Array(Tab.allCases)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(resolvedTabs.enumerated()), id: \.element) { index, tab in
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
            }
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
    
    private var selectedGradient: LinearGradient {
        theme.selectedBackground(for: tab, index: index)
    }
    
    private var unselectedGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Shortened title for compact display
    private var compactTitle: String {
        let title = tab.title
        // Shorten long titles
        switch title.lowercased() {
        case "volatility": return "Volatility"
        case "momentum": return "Momentum"
        default: return title
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(compactTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? selectedGradient : unselectedGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppColors.statusInfo40 : Color.clear, lineWidth: 1)
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
    var iconColor: Color = AppColors.surfaceGray40
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.surfaceWhite70)
            
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
                .foregroundColor(AppColors.surfaceWhite30)
            
            Text(searchText.isEmpty ? message : "No results for '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(AppColors.surfaceWhite50)
            
            Text(suggestion)
                .font(.caption)
                .foregroundColor(AppColors.surfaceWhite40)
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
func assetClassColor(_ assetClass: RLAssetClass) -> Color {
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
// MARK: - UNIFFIED VIEWS
// MARK: - ================================================================================================

struct UnifiedStaticBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            StaticPatternView()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED CONTENT CARD
// MARK: - ================================================================================================

/// A pressable card container with consistent styling and press animation
/// Use for: Markers, Announcements, Events, any tappable list item
struct UnifiedContentCard<Content: View>: View {
    let onTap: () -> Void
    var showUnreadBorder: Bool = false
    var showUnreadDot: Bool = false
    var isUnread: Bool = false
    var semanticBorderColor: Color? = nil
    var cornerRadius: CGFloat = 12
    @ViewBuilder let content: () -> Content

    @State private var isPressed: Bool = false

    private var fillOpacity: Double {
        if isUnread {
            return isPressed ? 0.10 : 0.08
        }
        return isPressed ? 0.06 : 0.03
    }

    private var borderColor: Color {
        if let semantic = semanticBorderColor {
            return semantic
        }
        if showUnreadBorder || isUnread {
            return AppColors.accentColor.opacity(0.4)
        }
        return AppColors.surfaceWhite08
    }

    var body: some View {
        Button(action: onTap) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppColors.systemWhite.opacity(fillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if showUnreadDot {
                        Circle()
                            .fill(AppColors.accentColor)
                            .frame(width: 8, height: 8)
                            .padding(8)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Notification Styling Helper

/// Shared styling values for read/unread notification states.
/// Use across NotificationCard, AnnouncementRowView, EventRowView for consistency.
struct NotificationStyling {
    let isRead: Bool

    var titleColor: Color {
        isRead ? AppColors.whiteText.opacity(0.8) : AppColors.whiteText
    }
    var bodyColor: Color {
        isRead ? AppColors.whiteText.opacity(0.5) : AppColors.whiteText.opacity(0.72)
    }
    var timeColor: Color {
        isRead ? AppColors.whiteText.opacity(0.32) : AppColors.whiteText.opacity(0.55)
    }
    var iconOpacity: Double {
        isRead ? 0.72 : 1.0
    }
    var iconBadgeOpacity: Double {
        isRead ? 0.14 : 0.20
    }
}

// MARK: - Marker List Specifics Section

/// Dark container for marker-specific detail content in list view cards.
/// Matches the visual style of the chart info box content area.
struct MarkerListSpecificsSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }
}

/// Small uppercase label for marker type within the specifics section.
struct MarkerListSpecificsLabel: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundColor(color)
            .tracking(0.4)
    }
}

// MARK: - ================================================================================================
// MARK: - MARKER ACTIVITY META CHIP
// MARK: - ================================================================================================

/// Small pill showing icon + text (e.g., timeframe "M5", type label).
/// Reused across all marker list item styles.
struct MarkerActivityMetaChip: View {
    let icon: String
    let text: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .semibold))
            Text(text)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(background)
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED AUTHOR FOOTER
// MARK: - ================================================================================================

/// Author footer bar with subtle background - sits at bottom of card
/// Use for: TopMarkerCard, Announcements, Events - distinct footer section style
struct UnifiedAuthorFooter: View {
    let username: String
    var isOnline: Bool = false
    let role: RLMemberRole
    let reputation: Int
    var accuracy: String? = nil
    var timeText: String? = nil
    var cornerRadius: CGFloat = 12
    var showOnlineStatus: Bool = false  // Default to hidden
    
    var body: some View {
        HStack(spacing: 4) {
            // Username
            Text(username)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.whiteText.opacity(0.9))
            
            // Online indicator (optional)
            if showOnlineStatus && isOnline {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 5, height: 5)
            }
            
            // Separator dot
            UnifiedSeparatorDot()
            
            // Role with color
            Text(role.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(role.color.opacity(0.9))
            
            // Separator dot
            UnifiedSeparatorDot()
            
            // Reputation
            HStack(spacing: 2) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 8))
                Text("\(reputation)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(AppColors.accentColor.opacity(0.9))
            
            // Accuracy
            if let accuracy = accuracy {
                UnifiedSeparatorDot()
                
                HStack(spacing: 2) {
                    Image(systemName: "target")
                        .font(.system(size: 8))
                    Text(accuracy)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(AppColors.statusPositive90)
            }
            
            Spacer()
            
            // Time (optional)
            if let time = timeText {
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.whiteText.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: cornerRadius,
                    bottomTrailing: cornerRadius,
                    topTrailing: 0
                )
            )
            .fill(AppColors.surfaceWhite06)
        )
    }
}

/// Author footer with RLGuildMemberDTO (for member-focused views)
struct UnifiedAuthorFooterFromMember: View {
    let author: RLGuildMemberDTO
    var timeText: String? = nil
    var cornerRadius: CGFloat = 12
    var showOnlineStatus: Bool = false   // Default to hidden
    var showFriendIcon: Bool = false     // Default to hidden
    var showBlockedIcon: Bool = true     // Show blocked by default
    
    var body: some View {
        HStack(spacing: 6) {
            // Blocked indicator
            if showBlockedIcon && author.isBlocked {
                Image(systemName: "nosign")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppColors.bearCandleRed)
            }
            
            // Username
            Text(author.username)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.whiteText.opacity(0.9))
            
            // Friend indicator (optional)
            if showFriendIcon && author.isFriend {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
            }
            
            // Online indicator (optional)
            if showOnlineStatus && author.isOnline {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 5, height: 5)
            }
            
            // Separator dot
            UnifiedSeparatorDot()
            
            // Role with color
            let role = author.memberRole
            Text(role.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(role.color.opacity(0.9))
            
            // Separator dot
            UnifiedSeparatorDot()
            
            // Reputation
            HStack(spacing: 2) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 8))
            Text("\(author.reputation)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(AppColors.accentColor.opacity(0.9))
            
            Spacer()
            
            // Time (optional)
            if let time = timeText {
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.whiteText.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: cornerRadius,
                    bottomTrailing: cornerRadius,
                    topTrailing: 0
                )
            )
            .fill(AppColors.surfaceWhite06)
        )
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED AUTHOR ROW (INLINE)
// MARK: - ================================================================================================

/// Inline author info row without background
/// Use for: When you need author info within content (not as a footer)
struct UnifiedAuthorRow: View {
    let username: String
    var isOnline: Bool = false
    let role: RLMemberRole
    let reputation: Int
    var accuracy: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text(username)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.whiteText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 40)
                .layoutPriority(1)
            
            // Online indicator
            if isOnline {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 5, height: 5)
            }
            
            UnifiedSeparatorDot()
            
            // Role with color
            Text(role.displayName)
                .font(.caption)
                .foregroundColor(role.color)
                .fontWeight(role.canModerate ? .bold : .regular)
                .lineLimit(1)
            
            UnifiedSeparatorDot()
            
            // Reputation
            Image(systemName: "shield.pattern.checkered")
                .font(.system(size: 9))
                .fontWeight(.bold)
                .foregroundColor(AppColors.accentColor)
            
            Text("\(reputation)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accentColor)
            
            if let accuracy = accuracy {
                UnifiedSeparatorDot()
                Image(systemName: "target")
                    .font(.system(size: 9))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text(accuracy)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
    }
}

/// Inline author row with RLGuildMemberDTO (for member-focused views)
struct UnifiedAuthorRowFromMember: View {
    let author: RLGuildMemberDTO
    var showFriendBadge: Bool = true
    var showBlockedBadge: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            // Blocked indicator
            if showBlockedBadge && author.isBlocked {
                Image(systemName: "nosign")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.bearCandleRed)
            }
            
            Text(author.username)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.whiteText)
            
            // Friend indicator
            if showFriendBadge && author.isFriend {
                Image(systemName: "person.crop.circle")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
            }
            
            // Online indicator
            if author.isOnline {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 5, height: 5)
            }
            
            UnifiedSeparatorDot()
            
            // Role with color
            let role = author.memberRole
            Text(role.displayName)
                .font(.caption)
                .foregroundColor(role.color)
                .fontWeight(role.canModerate ? .bold : .regular)
                .lineLimit(1)
            
            UnifiedSeparatorDot()
            
            // Reputation
            Image(systemName: "shield.pattern.checkered")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.accentColor)
            
            Text("\(author.reputation)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accentColor)
            
            if let accuracy = author.accuracyFormatted {
                UnifiedSeparatorDot()
                Image(systemName: "target")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text(accuracy)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED SEPARATOR DOT
// MARK: - ================================================================================================

/// Small separator dot used between inline elements
struct UnifiedSeparatorDot: View {
    var size: CGFloat = 3
    var opacity: Double = 0.3
    var horizontalPadding: CGFloat = 2
    
    var body: some View {
        Circle()
            .fill(AppColors.whiteText.opacity(opacity))
            .frame(width: size, height: size)
            .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED ROLE BADGE
// MARK: - ================================================================================================

/// Compact role + reputation badge for use in any user display context
/// Shows: "Admin . shield 142" in a compact horizontal layout
/// Handles Owner distinction: if isOwner is true, shows "Owner" instead of the role name
struct UnifiedRoleBadge: View {
    let roleName: String
    let roleColor: Color
    let reputation: Int
    var accuracy: String? = nil
    var isOwner: Bool = false
    var showReputation: Bool = true
    var fontSize: Font = .caption
    var iconSize: Font = .caption2

    var body: some View {
        HStack(spacing: 2) {
            if isOwner {
                Text("Owner")
                    .font(fontSize)
                    .foregroundColor(AppColors.accentColor)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            } else {
                Text(roleName)
                    .font(fontSize)
                    .foregroundColor(roleColor)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            if showReputation {
                UnifiedSeparatorDot(size: 4, opacity: 0.7)

                Image(systemName: "shield.pattern.checkered")
                    .font(iconSize)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)

                Text("\(reputation)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentColor)
                
                if let accuracy = accuracy {
                    UnifiedSeparatorDot(size: 3, opacity: 0.5)
                    
                    Image(systemName: "target")
                        .font(iconSize)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(accuracy)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
    }

    init(roleName: String, roleColor: Color, reputation: Int, accuracy: String? = nil, isOwner: Bool = false, showReputation: Bool = true, fontSize: Font = .caption, iconSize: Font = .caption2) {
        self.roleName = roleName
        self.roleColor = roleColor
        self.reputation = reputation
        self.accuracy = accuracy
        self.isOwner = isOwner
        self.showReputation = showReputation
        self.fontSize = fontSize
        self.iconSize = iconSize
    }

    init(member: RLGuildMemberDTO, isOwner: Bool = false, showReputation: Bool = true, fontSize: Font = .caption, iconSize: Font = .caption2) {
        self.roleName = member.memberRole.displayName
        self.roleColor = member.memberRole.color
        self.reputation = member.reputation
        self.accuracy = member.accuracyFormatted
        self.isOwner = isOwner
        self.showReputation = showReputation
        self.fontSize = fontSize
        self.iconSize = iconSize
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED STATS ROW
// MARK: - ================================================================================================

/// Stats row with comments and likes (for markers, posts, etc.)
struct UnifiedStatsRow: View {
    let commentCount: Int
    let likeCount: Int
    var isLiked: Bool = false
    var isLikeAnimating: Bool = false
    var onLike: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            // Comments
            HStack(spacing: 2) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 9))
                Text("\(commentCount)")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(AppColors.whiteText.opacity(0.5))
            
            // Likes
            if let onLike = onLike {
                Button(action: onLike) {
                    likeContent
                }
                .buttonStyle(.plain)
            } else {
                likeContent
            }
        }
    }
    
    private var likeContent: some View {
        HStack(spacing: 2) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 9))
                .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
            Text("\(likeCount)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(isLiked ? .red : AppColors.whiteText.opacity(0.5))
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED ICON BADGE
// MARK: - ================================================================================================

/// Circular icon badge with background color
/// Use for: Marker type icons, category icons, etc.
struct UnifiedIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 32
    var iconSize: CGFloat = 14
    var backgroundOpacity: Double = 0.2
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(backgroundOpacity))
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - UNIFIED MARKER BADGE (chart-style marker icon)

enum UnifiedMarkerBadgeSizeToken {
    case tiny
    case small
    case medium
    case large

    var diameter: CGFloat {
        switch self {
        case .tiny:
            return 20
        case .small:
            return 24
        case .medium:
            return 32
        case .large:
            return 44
        }
    }
}

/// Chart-style marker badge matching in-chart markers:
/// dark neutral fill, solid marker-color border, and same-color icon.
struct UnifiedMarkerBadge: View {
    let intent: RLMarkerIntent
    let displayColor: Color
    var alertSeverity: MarkerAlertSeverity? = nil
    var size: CGFloat = 32
    var emoji: String? = nil
    var textLabel: String? = nil
    var isSelected: Bool = false

    init(
        intent: RLMarkerIntent,
        displayColor: Color? = nil,
        alertSeverity: MarkerAlertSeverity? = nil,
        size: CGFloat = 32,
        sizeToken: UnifiedMarkerBadgeSizeToken? = nil,
        emoji: String? = nil,
        textLabel: String? = nil,
        isSelected: Bool = false
    ) {
        self.intent = intent
        self.displayColor = displayColor ?? intent.color
        self.alertSeverity = alertSeverity
        self.size = sizeToken?.diameter ?? size
        self.emoji = emoji
        self.textLabel = textLabel
        self.isSelected = isSelected
    }

    private var glassTint: Color {
        MarkerVisualSpec.glassTint(for: intent, severity: alertSeverity)
    }

    private var strokeColor: Color {
        MarkerVisualSpec.borderColor(for: intent, severity: alertSeverity)
    }

    private var iconColor: Color {
        MarkerVisualSpec.iconPrimaryColor(for: intent, severity: alertSeverity)
    }

    private var iconSize: CGFloat {
        MarkerVisualSpec.iconSize(for: size, intent: intent)
    }

    private var resolvedSymbol: String {
        MarkerVisualSpec.symbol(for: intent, severity: alertSeverity)
    }

    private var resolvedPalette: [Color] {
        MarkerVisualSpec.palette(for: intent, severity: alertSeverity)
    }

    var body: some View {
        ZStack {
            // Glass background
            Circle().fill(.ultraThinMaterial)
            Circle().fill(glassTint)
            Circle().stroke(strokeColor, lineWidth: MarkerVisualSpec.glassStrokeWidth)

            // Icon
            if intent == .reaction, let emoji = emoji {
                Text(emoji)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(iconColor)
            } else if let label = textLabel, !label.isEmpty {
                Text(label)
                    .font(.system(size: iconSize * 0.88, weight: .bold))
                    .foregroundColor(iconColor)
            } else {
                paletteSymbol
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(
            color: glassTint.opacity(MarkerVisualSpec.glassShadowOpacity),
            radius: MarkerVisualSpec.glassShadowRadius,
            x: 0, y: 1
        )
    }

    @ViewBuilder
    private var paletteSymbol: some View {
        if resolvedPalette.count >= 3 {
            Image(systemName: resolvedSymbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(resolvedPalette[0], resolvedPalette[1], resolvedPalette[2])
        } else if resolvedPalette.count == 2 {
            Image(systemName: resolvedSymbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(resolvedPalette[0], resolvedPalette[1])
        } else {
            Image(systemName: resolvedSymbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(iconColor)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED IMPORTANCE BADGE
// MARK: - ================================================================================================

/// Badge for important items (announcements, alerts)
struct UnifiedImportanceBadge: View {
    var text: String = "IMPORTANT"
    var backgroundColor: Color = AppColors.bearCandleRed.opacity(0.8)
    var textColor: Color = .white
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED DATE PILL
// MARK: - ================================================================================================

/// Date pill for events (shows month and day)
struct UnifiedDatePill: View {
    let date: Date
    var width: CGFloat = 50
    
    private var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df
    }
    
    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("d")
        return df
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(monthFormatter.string(from: date))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.accentColor)
            Text(dayFormatter.string(from: date))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
        }
        .frame(width: width)
        .padding(.vertical, 8)
        .background(AppColors.surfaceWhite10)
        .cornerRadius(8)
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED MEMBER AVATAR
// MARK: - ================================================================================================

/// Avatar circle with initials and online indicator
/// Use for: User lists, leaderboards, member rows
struct UnifiedMemberAvatar: View {
    let username: String
    var avatarURL: String? = nil
    var isOnline: Bool = false
    var size: CGFloat = 40
    var showOnlineIndicator: Bool = true
    
    private var initials: String {
        String(username.prefix(2)).uppercased()
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .overlay(
                                Text(initials)
                                    .font(.system(size: size * 0.35, weight: .bold))
                                    .foregroundColor(AppColors.accentColor)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.35, weight: .bold))
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            if showOnlineIndicator {
                Circle()
                    .fill(isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(AppColors.drawerBackground, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED MEMBER ROW
// MARK: - ================================================================================================

/// Standard member row for user lists
/// Use for: Guild member lists, friend lists, search results
struct UnifiedMemberRow: View {
    let user: RLGuildMemberDTO
    let onTap: () -> Void
    var showReputation: Bool = true
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                UnifiedMemberAvatar(
                    username: user.username,
                    avatarURL: user.avatarUrl,
                    isOnline: user.isOnline
                )
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    // Username with badges
                    HStack(spacing: 4) {
                        if user.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if user.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                        }
                    }
                    
                    // Role · reputation · accuracy (unified)
                    UnifiedRoleBadge(member: user, showReputation: showReputation)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.systemWhite.opacity(isPressed ? 0.06 : 0.03))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED GUILD MEMBER ROW (REAL API)
// MARK: - ================================================================================================

/// Standard member row for real API guild members
/// Use for: Guild member lists backed by RLGuildMemberDTO
struct UnifiedGuildMemberRow: View {
    let user: RLGuildMemberDTO
    let onTap: () -> Void
    var showReputation: Bool = true
    
    @EnvironmentObject var rlAppState: RLAppState
    @State private var isPressed: Bool = false
    
    private var isOnline: Bool {
        rlAppState.effectiveOnlineStatus(userId: user.userId, fallback: user.isOnline)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                UnifiedMemberAvatar(
                    username: user.username,
                    avatarURL: user.avatarUrl,
                    isOnline: isOnline
                )
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    // Username with badges
                    HStack(spacing: 4) {
                        if user.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if user.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                        }
                    }
                    
                    // Role and reputation
                    UnifiedRoleBadge(member: user, showReputation: showReputation)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.systemWhite.opacity(isPressed ? 0.06 : 0.03))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED LEADERBOARD ROW
// MARK: - ================================================================================================

/// Leaderboard row with rank indicator
/// Use for: Leaderboard lists with ranking
struct UnifiedLeaderboardRow: View {
    let user: RLGuildMemberDTO
    let rank: Int
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    /// Whether this is a top 3 position
    private var isTopRank: Bool { rank <= 3 }
    
    /// Rank color based on position
    private var rankColor: Color {
        switch rank {
        case 1: return AppColors.systemYellow
        case 2: return AppColors.surfaceGray80
        case 3: return AppColors.statusWarning80
        default: return AppColors.whiteText.opacity(0.5)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Rank indicator
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
                    .frame(width: 24)
                
                // Avatar
                UnifiedMemberAvatar(
                    username: user.username,
                    avatarURL: user.avatarUrl,
                    isOnline: user.isOnline,
                    size: 40
                )
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    // Username with badges
                    HStack(spacing: 4) {
                        if user.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if user.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                        }
                    }
                    
                    // Role
                        let role = user.memberRole
                        Text(role.displayName)
                            .font(.caption)
                            .foregroundColor(role.color)
                            .fontWeight(role.canModerate ? .bold : .regular)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Reputation (prominent on right)
                HStack(spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("\(user.reputation)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.systemWhite.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isTopRank ? rankColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
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
        AppColors.systemBlack.ignoresSafeArea()
        
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
                            .background(AppColors.surfaceWhite05)
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

// MARK: - ================================================================================================
// MARK: - TRACKING STATE PILL
// MARK: - ================================================================================================

/// Unified capsule badge showing the tracking state with a pulsing dot for live states
/// or a terminal icon for resolved states (TP Hit, SL Hit, Expired).
/// Use for: Setup marker state display across all list rows and detail views.
struct TrackingStatePill: View {
    let state: RLTrackingState
    var size: PillSize = .standard

    enum PillSize {
        case compact  // list rows (bottom bar, left drawer)
        case standard // detail views

        var fontSize: CGFloat {
            switch self {
            case .compact: return 9
            case .standard: return 10
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact: return 8
            case .standard: return 10
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .compact: return 6
            case .standard: return 8
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return 7
            case .standard: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact: return 3
            case .standard: return 5
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 4
            case .standard: return 5
            }
        }
    }

    @State private var dotPulse: Bool = false

    private var isLive: Bool {
        state == .armed || state == .active
    }

    private var terminalIcon: String? {
        switch state {
        case .tpHit: return "checkmark.circle.fill"
        case .slHit: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            if isLive {
                Circle()
                    .fill(state.color)
                    .frame(width: size.dotSize, height: size.dotSize)
                    .scaleEffect(dotPulse ? 1.3 : 0.8)
                    .opacity(dotPulse ? 1.0 : 0.6)
            } else if let icon = terminalIcon {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .bold))
                    .foregroundColor(state.color)
            }

            Text(state.displayName.uppercased())
                .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(state.color)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            Capsule()
                .fill(state.color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(state.color.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            if isLive {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    dotPulse = true
                }
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - APPROACHING LEVEL CHIP
// MARK: - ================================================================================================

/// Secondary chip showing proximity to TP or SL price levels.
/// Only renders for `.approachingTP` or `.approachingSL` states.
/// Use for: Inline next to TrackingStatePill on active setup markers.
struct ApproachingLevelChip: View {
    let status: MarkerPredictionProgressStatus

    private var shouldRender: Bool {
        status == .approachingTP || status == .approachingSL
    }

    private var label: String {
        switch status {
        case .approachingTP: return "Near TP"
        case .approachingSL: return "Near SL"
        default: return ""
        }
    }

    private var chipColor: Color {
        switch status {
        case .approachingTP: return .green
        case .approachingSL: return .orange
        default: return .clear
        }
    }

    var body: some View {
        if shouldRender {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(chipColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(chipColor.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(chipColor.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Unified Setup Progress Strip

/// Size variant for the setup progress strip.
enum SetupStripSize {
    /// Chart info box: 12px bar, 10px dot, positional captions, card background with tinted border
    case compact
    /// List cards (drawer, bottom bar): 8px bar, 10px dot, inline HStack labels
    case standard
    /// Detail view: 12px bar, 14px dot, PNL header with R:R badge, VStack labels, card background
    case detail
}

/// Unified live setup progress visualization used across all marker views.
/// Replaces LiveSetupProgressStrip, CompactSetupSwingStripCard, and DetailSetupProgressStrip.
struct UnifiedSetupProgressStrip: View {
    let metrics: LiveSetupMetrics
    let size: SetupStripSize
    var formatPrice: ((Double) -> String)? = nil

    private var targetTint: Color { RLComponentType.levelTp.color }
    private var stopTint: Color { RLComponentType.levelSl.color }
    private var entryTint: Color { RLComponentType.levelEntry.color }
    private var swingTint: Color { metrics.isMovingTowardTarget ? targetTint : stopTint }

    private var entryPos: CGFloat {
        CGFloat(min(max(metrics.entryPosition, 0), 1))
    }

    private var currentPos: CGFloat {
        CGFloat(min(max(metrics.currentPosition, 0), 1))
    }

    private var dotSize: CGFloat {
        size == .detail ? 14 : 10
    }

    private var barHeight: CGFloat {
        size == .standard ? 8 : 12
    }

    private var dotStrokeWidth: CGFloat {
        size == .detail ? 2 : 1.5
    }

    private var riskRewardRatio: String? {
        let reward = abs(metrics.targetPrice - metrics.entryPrice)
        let risk = abs(metrics.entryPrice - metrics.stopLossPrice)
        guard risk > 0 else { return nil }
        return String(format: "%.1f", reward / risk)
    }

    private func priceText(_ price: Double) -> String {
        formatPrice?(price) ?? String(format: "%.5f", price)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .detail ? 10 : size == .compact ? 7 : 5) {
            if size == .detail {
                detailHeader
            }

            progressBar

            switch size {
            case .compact:
                compactLabels
            case .standard:
                standardLabels
            case .detail:
                detailLabels
            }
        }
        .modifier(StripContainerModifier(size: size, borderTint: swingTint))
    }

    // MARK: - Detail Header (PNL + R:R)

    private var detailHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: metrics.isMovingTowardTarget ? "waveform.path.ecg" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%@%.2f%%", metrics.currentPnL >= 0 ? "+" : "", metrics.currentPnL))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
            }
            .foregroundColor(swingTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(swingTint.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(swingTint.opacity(0.3), lineWidth: 1)
                    )
            )

            if let rr = riskRewardRatio {
                Text("R:R \(rr)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite70)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppColors.surfaceWhite08)
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.surfaceWhite15, lineWidth: 1)
                            )
                    )
            }

            Spacer()

            Text(priceText(metrics.currentPrice))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(swingTint)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            let safeWidth = max(geometry.size.width, 1)
            let entryX = safeWidth * entryPos
            let currentX = safeWidth * currentPos
            let swingStart = min(entryX, currentX)
            let swingWidth = max(abs(currentX - entryX), 2)
            let halfDot = dotSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.surfaceWhite08)

                HStack(spacing: 0) {
                    if metrics.isLong {
                        Rectangle()
                            .fill(stopTint.opacity(0.30))
                            .frame(width: entryX)
                        Rectangle()
                            .fill(targetTint.opacity(0.30))
                    } else {
                        Rectangle()
                            .fill(targetTint.opacity(0.30))
                            .frame(width: entryX)
                        Rectangle()
                            .fill(stopTint.opacity(0.30))
                    }
                }
                .clipShape(Capsule())

                Capsule()
                    .fill(swingTint)
                    .frame(width: swingWidth)
                    .offset(x: swingStart)

                Capsule()
                    .fill(AppColors.surfaceWhite85.opacity(0.65))
                    .frame(width: 2)
                    .offset(x: max(min(entryX - 1, safeWidth - 2), 0))

                Circle()
                    .fill(swingTint)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .stroke(AppColors.systemBlack.opacity(0.55), lineWidth: dotStrokeWidth)
                    )
                    .offset(x: max(min(currentX - halfDot, safeWidth - dotSize), 0), y: -1)
            }
        }
        .frame(height: barHeight)
    }

    // MARK: - Compact Labels (positional captions for info box)

    private var compactLabels: some View {
        GeometryReader { geometry in
            let safeWidth = max(geometry.size.width, 1)
            let slPos = CGFloat(metrics.stopLossPosition)
            let tpPos = CGFloat(metrics.targetPosition)

            ZStack(alignment: .leading) {
                Text("SL")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(stopTint)
                    .position(
                        x: max(14, min(safeWidth - 14, safeWidth * slPos)),
                        y: 7
                    )
                Text("Entry")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(entryTint)
                    .position(
                        x: max(14, min(safeWidth - 14, safeWidth * entryPos)),
                        y: 7
                    )
                Text("TP")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(targetTint)
                    .position(
                        x: max(14, min(safeWidth - 14, safeWidth * tpPos)),
                        y: 7
                    )
            }
        }
        .frame(height: 14)
    }

    // MARK: - Standard Labels (inline HStack for list cards)

    private var standardLabels: some View {
        HStack {
            Text("SL \(priceText(metrics.stopLossPrice))")
                .foregroundColor(stopTint)

            Spacer()

            Text("ENTRY \(priceText(metrics.entryPrice))")
                .foregroundColor(AppColors.surfaceWhite70)

            Spacer()

            Text("TP \(priceText(metrics.targetPrice))")
                .foregroundColor(targetTint)
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
    }

    // MARK: - Detail Labels (VStack labels with price below)

    private var detailLabels: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("SL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(stopTint.opacity(0.7))
                Text(priceText(metrics.stopLossPrice))
                    .foregroundColor(stopTint)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("ENTRY")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.surfaceWhite50)
                Text(priceText(metrics.entryPrice))
                    .foregroundColor(AppColors.surfaceWhite70)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("TP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(targetTint.opacity(0.7))
                Text(priceText(metrics.targetPrice))
                    .foregroundColor(targetTint)
            }
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
    }
}

/// Applies the appropriate container styling based on strip size.
private struct StripContainerModifier: ViewModifier {
    let size: SetupStripSize
    let borderTint: Color

    func body(content: Content) -> some View {
        switch size {
        case .compact:
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AppColors.surfaceWhite08)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(borderTint.opacity(0.24), lineWidth: 1)
                        )
                )
        case .standard:
            content
        case .detail:
            content
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surfaceWhite04)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderTint.opacity(0.25), lineWidth: 1)
                        )
                )
        }
    }
}
