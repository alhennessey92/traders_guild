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
