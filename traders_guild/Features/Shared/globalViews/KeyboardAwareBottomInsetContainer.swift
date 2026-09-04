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
                contentBottomPadding: mode == .chat ? 48 : 20
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

enum KeyboardPinnedBottomInsetWindowInsets {
    /// How much of the screen the keyboard covers, from a keyboard notification.
    ///
    /// Reported in screen coordinates, so an off-screen end frame (the keyboard
    /// dismissing, or a hardware keyboard's shortcut bar sliding away) yields 0
    /// rather than a negative inset.
    static func keyboardInset(from notification: Notification) -> CGFloat {
        guard let endFrame = notification.userInfo?[
            UIResponder.keyboardFrameEndUserInfoKey
        ] as? CGRect else { return 0 }
        let screenHeight = UIScreen.main.bounds.height
        return max(screenHeight - endFrame.minY, 0)
    }

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
    /// How far the keyboard reaches up the screen, 0 when it is down.
    ///
    /// Not read from the `GeometryReader`'s proxy, which is where this used to
    /// come from: the reader below spans the container, and a view that ignores
    /// a safe area is *given the region and reports the inset as zero*. So the
    /// proxy answered 0 whether or not a keyboard was up — measured — and
    /// `keyboardVisible` below could never be true. The notification is the
    /// only signal that survives ignoring the safe area.
    @State private var keyboardInset: CGFloat = 0

    func body(content: Content) -> some View {
        // `.container, .bottom` is load-bearing, not decoration.
        //
        // A plain `GeometryReader` is laid out *inside* the safe area, so on a
        // notched phone its frame stopped 34pt short of the screen and
        // `proxy.safeAreaInsets.bottom` read 0 — measured at
        // `reader=(0, 54, 393, 764)` in an 852pt window. Two things followed:
        // the footer's `footerBottomPadding` was applied to a container that
        // had *already* been inset, lifting the button 34pt clear of the home
        // indicator and stealing the same 34pt from the content; and
        // `keyboardVisible` (`geometryBottomInset > hardwareInset + 1`) could
        // never be true, so the keyboard branch below was dead and a form at
        // its tallest ran its last field under the pinned footer.
        //
        // Spanning the container restores what the rest of this file assumes:
        // the reader reaches the screen edge, and the proxy reports the real
        // bottom inset — the home indicator's, or the keyboard's when it is up.
        GeometryReader { _ in
            let hardwareInset = KeyboardPinnedBottomInsetWindowInsets.bottomSafeAreaInset
            let layout = KeyboardPinnedFooterLayout.resolve(
                mode: mode,
                // With the keyboard down this is the home-indicator inset, so
                // `resolve` reads "not visible"; with it up it is the
                // keyboard's own height. Same contract the proxy was meant to
                // satisfy, from a source that still works.
                geometryBottomInset: max(keyboardInset, hardwareInset),
                hardwareBottomInset: hardwareInset
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
        .ignoresSafeArea(.container, edges: .bottom)
        .onPreferenceChange(KeyboardPinnedFooterHeightPreferenceKey.self) { newValue in
            guard abs(footerHeight - newValue) > 0.5 else { return }
            footerHeight = newValue
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )
        ) { note in
            keyboardInset = KeyboardPinnedBottomInsetWindowInsets.keyboardInset(from: note)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            keyboardInset = 0
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
