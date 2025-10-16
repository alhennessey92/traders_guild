//
//  BackButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 15/10/2025.
//

import SwiftUI
struct BackButton: View {
    let title: String
    let foregroundColor: Color
    let action: () -> Void    // no default
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .scaleEffect(0.9)
                .foregroundColor(foregroundColor)
                .padding()
                
                
        }
        .buttonStyle(.borderless)
    }
}
