//
//  StandardActionButtonFullWidth.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
import SwiftUI
struct StandardActionButtonFullWidth: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: (() -> Void) // ✅ default to nil
    
    
    
    var body: some View {
        Button(action: action) {
            
            Text(title)
                .font(.headline)
                .scaleEffect(0.9)
                .foregroundColor(foregroundColor)
                .padding(.vertical, 14)      // vertical space, dynamic height
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
    //          .cornerRadius(12)
                .clipShape(Capsule())
                .padding()
                
            
        }
    }
    
}
