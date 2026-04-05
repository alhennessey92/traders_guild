import SwiftUI

struct UnifiedComponentsScaffold<Tab: UnifiedTabItem, Content: View>: View where Tab.AllCases: RandomAccessCollection {
    let title: String
    let subtitle: String
    let headerIcon: String
    var headerIconTint: Color = AppColors.statusInfo95
    var headerIconBackground: Color = AppColors.statusInfo22
    @Binding var selectedTab: Tab
    var tabSize: UnifiedTabSize = .compact
    var tabTheme: UnifiedTabTheme = .subTab
    var tabSpacing: CGFloat = 6
    @ViewBuilder let content: (Tab) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: tabSize,
                theme: tabTheme,
                spacing: tabSpacing
            )

            content(selectedTab)
        }
        .padding(.trailing, 2)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(headerIconBackground.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: headerIcon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(headerIconTint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            headerIconTint.opacity(0.22),
                            headerIconTint.opacity(0.12),
                            AppColors.whiteText.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(headerIconTint.opacity(0.34), lineWidth: 1)
                )
        )
    }
}
