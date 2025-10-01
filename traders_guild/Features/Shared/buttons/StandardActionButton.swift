//
//  StandardActionButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
import SwiftUI

/// Generic full-width button for login/signup
struct StandardActionButton: View {
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
                .padding(.horizontal, 30)
                
                .background(backgroundColor)
//                .cornerRadius(12)
                .clipShape(Capsule())
                
                
                
            
        }
        
    }
    
}


