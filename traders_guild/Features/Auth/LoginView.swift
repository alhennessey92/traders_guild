//
//  LoginView.swift
//  traders_guild
//

import SwiftUI

/// Backward-compatible wrapper kept for call sites still referencing LoginView.
struct LoginView: View {
    var body: some View {
        SigninEmailView()
    }
}
