//
//  PlatformViewModifiers.swift
//  traders_guild
//
//  SwiftUI modifiers whose parameter types or implementations only exist on
//  iOS. The UIKit branches preserve the shipped modifier calls exactly; macOS
//  deliberately leaves the view unchanged.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum PlatformNavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

enum PlatformKeyboardType {
    case `default`
    case numberPad
    case decimalPad
    case emailAddress
    case asciiCapable
}

enum PlatformTextContentType {
    case newPassword
    case password
    case emailAddress
    case username
    case oneTimeCode
}

extension View {

    @ViewBuilder
    func platformNavigationBarTitleDisplayMode(
        _ displayMode: PlatformNavigationBarTitleDisplayMode
    ) -> some View {
        #if canImport(UIKit)
        navigationBarTitleDisplayMode(displayMode.uiKitValue)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformKeyboardType(_ keyboardType: PlatformKeyboardType) -> some View {
        #if canImport(UIKit)
        self.keyboardType(keyboardType.uiKitValue)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformTextContentType(_ textContentType: PlatformTextContentType?) -> some View {
        #if canImport(UIKit)
        self.textContentType(textContentType?.uiKitValue)
        #else
        self
        #endif
    }

    /// `.toolbarBackground(_, for: .navigationBar)` — the `.navigationBar`
    /// placement is iOS-only. macOS toolbars take their background from the
    /// window, so there is nothing to set.
    @ViewBuilder
    func platformNavigationBarBackground<S: ShapeStyle>(_ style: S) -> some View {
        #if canImport(UIKit)
        self.toolbarBackground(style, for: .navigationBar)
        #else
        self
        #endif
    }

    /// `.toolbarBackground(_ visibility:, for: .navigationBar)` — the visibility
    /// overload, as distinct from the ShapeStyle one above.
    @ViewBuilder
    func platformNavigationBarBackground(_ visibility: Visibility) -> some View {
        #if canImport(UIKit)
        self.toolbarBackground(visibility, for: .navigationBar)
        #else
        self
        #endif
    }

    /// `.navigationBarBackButtonHidden(_:)` is iOS-only; macOS has no back button
    /// in the toolbar to hide.
    @ViewBuilder
    func platformNavigationBarBackButtonHidden(_ hidden: Bool = true) -> some View {
        #if canImport(UIKit)
        self.navigationBarBackButtonHidden(hidden)
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
private extension PlatformNavigationBarTitleDisplayMode {
    var uiKitValue: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .automatic: return .automatic
        case .inline: return .inline
        case .large: return .large
        }
    }
}

private extension PlatformKeyboardType {
    var uiKitValue: UIKeyboardType {
        switch self {
        case .asciiCapable: return .asciiCapable
        case .default: return .default
        case .numberPad: return .numberPad
        case .decimalPad: return .decimalPad
        case .emailAddress: return .emailAddress
        }
    }
}

private extension PlatformTextContentType {
    var uiKitValue: UITextContentType {
        switch self {
        case .newPassword: return .newPassword
        case .password: return .password
        case .emailAddress: return .emailAddress
        case .username: return .username
        case .oneTimeCode: return .oneTimeCode
        }
    }
}
#endif


/// Text-input autocapitalisation. Both spellings are iOS-only — macOS has no
/// on-screen keyboard to configure — so both no-op there.
enum PlatformAutocapitalization {
    case never, words, sentences, characters
}

extension View {
    @ViewBuilder
    func platformAutocapitalization(_ mode: PlatformAutocapitalization) -> some View {
        #if canImport(UIKit)
        switch mode {
        case .never:      self.textInputAutocapitalization(.never)
        case .words:      self.textInputAutocapitalization(.words)
        case .sentences:  self.textInputAutocapitalization(.sentences)
        case .characters: self.textInputAutocapitalization(.characters)
        }
        #else
        self
        #endif
    }
}

extension View {
    /// `.toolbarColorScheme(_, for: .navigationBar)` — iOS-only placement.
    @ViewBuilder
    func platformNavigationBarColorScheme(_ scheme: ColorScheme?) -> some View {
        #if canImport(UIKit)
        self.toolbarColorScheme(scheme, for: .navigationBar)
        #else
        self
        #endif
    }
}

extension View {
    /// `.toolbar(.hidden, for: .navigationBar)` — iOS-only placement. macOS has
    /// no navigation bar to hide.
    @ViewBuilder
    func platformHideNavigationBar() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

extension View {
    /// `fullScreenCover` is iOS-only. On macOS a sheet is the closest thing — a
    /// Mac window has no "full screen" to cover in that sense.
    @ViewBuilder
    func platformFullScreenCover<C: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        #if canImport(UIKit)
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    /// The paged TabView style is iOS-only; macOS falls back to the automatic one.
    @ViewBuilder
    func platformPageTabViewStyle() -> some View {
        #if canImport(UIKit)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self.tabViewStyle(.automatic)
        #endif
    }
}

extension Color {
    /// `Color(.systemGray4)` / `.systemGray5` are UIKit palette entries. macOS
    /// has no numbered grey scale, so these map to the nearest semantic controls.
    static var platformSystemGray4: Color {
        #if canImport(UIKit)
        return Color(.systemGray4)
        #else
        return Color(nsColor: .separatorColor)
        #endif
    }

    static var platformSystemGray5: Color {
        #if canImport(UIKit)
        return Color(.systemGray5)
        #else
        return Color(nsColor: .controlColor)
        #endif
    }
}

/// Toolbar placements. `.topBarLeading` / `.navigationBarLeading` are iOS-only;
/// macOS uses `.navigation` and `.primaryAction`.
extension ToolbarItemPlacement {
    static var platformLeading: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }

    static var platformTrailing: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .topBarTrailing
        #else
        return .primaryAction
        #endif
    }
}

extension View {
    /// The wheel date-picker style does not exist on macOS, which uses a stepper
    /// field instead.
    @ViewBuilder
    func platformWheelDatePickerStyle() -> some View {
        #if canImport(UIKit)
        self.datePickerStyle(.wheel)
        #else
        self.datePickerStyle(.field)
        #endif
    }
}

#if !canImport(UIKit)
/// Stand-ins for the modifiers defined in KeyboardDismissal.swift, which is an
/// iOS-only file excluded from the macOS target. A Mac has no software keyboard
/// to dismiss, so these are no-ops rather than reimplementations.
extension View {
    func dismissKeyboardOnTapBackground() -> some View { self }
    func dismissKeyboardOnTapAndDragBackground() -> some View { self }
}

/// The free function of the same name lives in that iOS-only file too. Many call
/// sites use it, so macOS gets a matching one rather than each site branching.
@MainActor
func dismissKeyboard() {
    PlatformKeyboard.dismiss()
}
#endif
