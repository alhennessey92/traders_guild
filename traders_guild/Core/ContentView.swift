//
//  ContentView.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/07/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.tgGradientBackground1, Color.tgGradientBackground2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea() // Optional: make it fill the screen

            VStack {
                Text("Traders Guild!")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .bold()
            }
            
            
        }
        
    }
}

#Preview {
    ContentView()
}
