//
//  RightDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI


struct RightDrawerMainView: View {
    
    let onClose: () -> Void
    
    @State private var dragTranslation: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with title and close button
            
            VStack{
                
                HStack {
                    
                    Button(action: {
                        withAnimation(AnimationConstants.standard) { onClose() }
                    }) {
                        Image(systemName: "chevron.right.dotted.chevron.right")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Users")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    
                }
                // Guild Name and icon
                HStack {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("KAOS")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    + Text(" Guild")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentColor)
                    
                    Spacer()
                    
                }
                .padding(.leading, 35)
                
                //Member counts
                HStack(spacing: 2) {
                    
                    Text("12")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Members")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Text("52")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Online")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 7, height: 7)
                        .padding(.top, 0)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    
                    Spacer()
                }
                
                .padding(.leading, 35)
//                .padding()
//                .padding(.bottom, 8)
//                .padding(.top, 60)
            }
            .padding(.leading, 25)
            .padding(.trailing, 25)
            .padding(.bottom, 4)
            .padding(.top, 60)
            
            
            // Placeholder content area with gesture support
            ScrollView {
                VStack(spacing: 16) {
                    Text("Drawer content goes here")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    // Add your drawer-specific content here
//                    ForEach(1...10, id: \.self) { index in
//                        HStack {
//                            Text("Item \(index)")
//                                .foregroundColor(.primary)
//                            Spacer()
//                            Image(systemName: "chevron.right")
//                                .foregroundColor(.secondary)
//                        }
//                        .padding()
//                        .background(Color.gray.opacity(0.1))
//                        .cornerRadius(8)
//                        .padding(.horizontal)
//                    }
                }
            }
            .simultaneousGesture(
                // Add drag gesture to ScrollView so it works inside drawer content
                DragGesture()
                    .onChanged { value in
                        // Only allow dismissal drags (left for left drawer, right for right drawer)
                        if (value.translation.width > 0) {
                            dragTranslation = value.translation.width
                        }
                    }
                    .onEnded { value in
                        // Check if dragged far enough to dismiss
                        let threshold = LayoutConstants.drawerDismissThreshold
                        if (dragTranslation > threshold) {
                            onClose()
                        }
                        dragTranslation = 0
                    }
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // the frosted glass base
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                // darken/tint the material
                AppColors.drawerBackground.opacity(0.6)               // tweak opacity
            }
        )
        .overlay(
            // Subtle border on the side facing the content
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .clipShape(
            // Custom corner rounding - only round corners opposite to the edge
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: LayoutConstants.cornerRadius,
                    bottomLeading: LayoutConstants.cornerRadius,
                    bottomTrailing: 0,
                    topTrailing: 0
                )
            )
        )
        .shadow(radius: LayoutConstants.shadowRadius)
        .ignoresSafeArea()
    }
}
