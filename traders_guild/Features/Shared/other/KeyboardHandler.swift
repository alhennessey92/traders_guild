
//
//  KeyboardHandler.swift
//  traders_guild
//
//  Shared keyboard height tracking utility
//  Used by: chartSheetChatView, MarkerDetailView, and any other view needing keyboard handling
//
//  IMPORTANT: Remove the KeyboardHandler class from chartSheetChatView.swift and
//  MarkerDetailView.swift after adding this file to avoid duplicate declarations.

import SwiftUI
import Combine

/// Tracks keyboard height for proper input positioning
/// Usage:
/// ```
/// @StateObject private var keyboardHandler = KeyboardHandler()
///
/// // In view body:
/// .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight - offsetAmount : 0)
/// .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
/// ```
final class KeyboardHandler: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }
            .sink { [weak self] height in
                self?.keyboardHeight = height
                self?.isKeyboardVisible = true
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.keyboardHeight = 0
                self?.isKeyboardVisible = false
            }
            .store(in: &cancellables)
    }
    
    /// Calculate bottom padding for an input view that should sit above keyboard
    /// - Parameter offsetForHiddenElements: Height of elements that should be hidden when keyboard is visible (e.g., tab bar)
    /// - Returns: The padding to apply to move the input above the keyboard
    func bottomPadding(offsetForHiddenElements: CGFloat = 0) -> CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        return keyboardHeight - offsetForHiddenElements
    }
}
