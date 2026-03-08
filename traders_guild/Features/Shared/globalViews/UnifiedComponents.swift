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
    case colored        // Per-tab colors (personal=yellow, guild=blue, etc.)
    case accent         // Uses AppColors.accentColor
    case emerald
    case amber
    case magenta
    
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
        case .emerald:
            return LinearGradient(
                colors: [Color.green.opacity(0.72), Color.teal.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .amber:
            return LinearGradient(
                colors: [Color.orange.opacity(0.72), Color.yellow.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .magenta:
            return LinearGradient(
                colors: [Color.pink.opacity(0.72), Color.indigo.opacity(0.58)],
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
        case .emerald:
            return Color.green.opacity(0.45)
        case .amber:
            return Color.orange.opacity(0.45)
        case .magenta:
            return Color.pink.opacity(0.45)
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
    var cornerRadius: CGFloat = 12
    @ViewBuilder let content: () -> Content
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(isPressed ? 0.06 : 0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    showUnreadBorder ? AppColors.accentColor.opacity(0.3) : Color.white.opacity(0.08),
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
                    .fill(Color.green)
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
                .foregroundColor(.green.opacity(0.9))
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
            .fill(Color.white.opacity(0.06))
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
                    .fill(Color.green)
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
            .fill(Color.white.opacity(0.06))
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
                    .fill(Color.green)
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
                    .fill(Color.green)
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

/// Chart-style marker badge matching in-chart markers:
/// dark neutral fill, solid marker-color border, and same-color icon.
struct UnifiedMarkerBadge: View {
    let intent: RLMarkerIntent
    let displayColor: Color
    var size: CGFloat = 32
    var emoji: String? = nil
    var textLabel: String? = nil
    var isSelected: Bool = false

    init(
        intent: RLMarkerIntent,
        displayColor: Color? = nil,
        size: CGFloat = 32,
        emoji: String? = nil,
        textLabel: String? = nil,
        isSelected: Bool = false
    ) {
        self.intent = intent
        self.displayColor = displayColor ?? intent.color
        self.size = size
        self.emoji = emoji
        self.textLabel = textLabel
        self.isSelected = isSelected
    }

    private var borderWidth: CGFloat {
        isSelected ? AppColors.markerSelectedBorderWidth : AppColors.markerUnselectedBorderWidth
    }

    private var iconColor: Color { displayColor }
    private var iconSize: CGFloat { size * 0.5 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .offset(x: 1.0, y: 1.0)
                .frame(width: size, height: size)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.markerNeutralFillTop, AppColors.markerNeutralFillBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            Circle()
                .stroke(displayColor, lineWidth: borderWidth)
                .frame(width: size, height: size)
            if intent == .reaction, let emoji = emoji {
                Text(emoji)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(iconColor)
            } else if let label = textLabel, !label.isEmpty {
                Text(label)
                    .font(.system(size: iconSize * 0.9, weight: .bold))
                    .foregroundColor(iconColor)
            } else {
                Image(systemName: intent.icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(iconColor)
            }
        }
        .frame(width: size, height: size)
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
        .background(Color.white.opacity(0.1))
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
                    .fill(Color.white.opacity(isPressed ? 0.06 : 0.03))
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
                    .fill(Color.white.opacity(isPressed ? 0.06 : 0.03))
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
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
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
                    .fill(Color.white.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03)))
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
