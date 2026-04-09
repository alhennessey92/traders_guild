import SwiftUI
import UIKit

enum KeyboardPinnedBottomInsetMode {
    case standard
    case chat
}

struct KeyboardPinnedFooterLayout: Equatable {
    let footerBottomPadding: CGFloat
    let contentBottomPadding: CGFloat

    static func resolve(
        mode: KeyboardPinnedBottomInsetMode,
        geometryBottomInset: CGFloat,
        hardwareBottomInset: CGFloat
    ) -> KeyboardPinnedFooterLayout {
        let clampedHardwareInset = max(hardwareBottomInset, 0)
        let keyboardVisible = geometryBottomInset > clampedHardwareInset + 1

        if keyboardVisible {
            return KeyboardPinnedFooterLayout(
                footerBottomPadding: 0,
                contentBottomPadding: mode == .chat ? 48 : 0
            )
        }

        switch mode {
        case .standard:
            return KeyboardPinnedFooterLayout(
                footerBottomPadding: clampedHardwareInset,
                contentBottomPadding: 0
            )
        case .chat:
            return KeyboardPinnedFooterLayout(
                footerBottomPadding: max(clampedHardwareInset - 28, 0),
                contentBottomPadding: 48
            )
        }
    }
}

private enum KeyboardPinnedBottomInsetWindowInsets {
    static var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { scene in
                (scene as? UIWindowScene)?.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom
            }
            .first ?? 0
    }
}

private struct KeyboardPinnedFooterHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct KeyboardPinnedBottomInsetModifier<Footer: View>: ViewModifier {
    let showsDivider: Bool
    let mode: KeyboardPinnedBottomInsetMode
    let footer: Footer
    let footerBackground: AnyView

    @State private var footerHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let layout = KeyboardPinnedFooterLayout.resolve(
                mode: mode,
                geometryBottomInset: proxy.safeAreaInsets.bottom,
                hardwareBottomInset: KeyboardPinnedBottomInsetWindowInsets.bottomSafeAreaInset
            )

            ZStack(alignment: .bottom) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, footerHeight + layout.contentBottomPadding)

                VStack(spacing: 0) {
                    if showsDivider {
                        Divider()
                    }
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.bottom, layout.footerBottomPadding)
                .background(alignment: .bottom) {
                    footerBackground
                        .ignoresSafeArea(edges: .bottom)
                }
                .background(
                    GeometryReader { footerProxy in
                        Color.clear
                            .preference(
                                key: KeyboardPinnedFooterHeightPreferenceKey.self,
                                value: footerProxy.size.height
                            )
                    }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onPreferenceChange(KeyboardPinnedFooterHeightPreferenceKey.self) { newValue in
            guard abs(footerHeight - newValue) > 0.5 else { return }
            footerHeight = newValue
        }
    }
}

extension View {
    func keyboardPinnedBottomInset<Footer: View>(
        showsDivider: Bool = false,
        mode: KeyboardPinnedBottomInsetMode = .standard,
        background: AnyView = AnyView(AppColors.sheetBackground),
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        modifier(
            KeyboardPinnedBottomInsetModifier(
                showsDivider: showsDivider,
                mode: mode,
                footer: footer(),
                footerBackground: background
            )
        )
    }
}

struct KeyboardAwareBottomInsetContainer<Content: View, Footer: View>: View {
    private let showsDivider: Bool
    private let mode: KeyboardPinnedBottomInsetMode
    private let footerBackground: AnyView
    private let content: Content
    private let footer: Footer

    init(
        showsDivider: Bool = false,
        mode: KeyboardPinnedBottomInsetMode = .standard,
        footerBackground: AnyView = AnyView(AppColors.sheetBackground),
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.showsDivider = showsDivider
        self.mode = mode
        self.footerBackground = footerBackground
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        content
            .keyboardPinnedBottomInset(showsDivider: showsDivider, mode: mode, background: footerBackground) {
                footer
            }
    }
}

/// Material-backed footer background for auth onboarding keyboards (light grey: less flat than bare sheet).
struct AuthKeyboardFooterChrome: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            AppColors.sheetBackground.opacity(ThemeManager.shared.currentTheme == .lightGrey ? 0.78 : 0.88)
        }
    }
}
