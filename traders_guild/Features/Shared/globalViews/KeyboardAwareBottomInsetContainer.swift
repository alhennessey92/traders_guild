import SwiftUI

struct KeyboardAwareBottomInsetContainer<Content: View, Footer: View>: View {
    private let showsDivider: Bool
    private let content: Content
    private let footer: Footer

    init(
        showsDivider: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.showsDivider = showsDivider
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if showsDivider {
                        Divider()
                    }
                    footer
                }
            }
    }
}
