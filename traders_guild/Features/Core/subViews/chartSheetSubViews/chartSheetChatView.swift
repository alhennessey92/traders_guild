//
//  chartSheetChatView.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/12/2025.
//

import SwiftUI


struct chartSheetChatView: View {
    
    @ObservedObject var chartViewModel: ChartViewModel
    
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Chart Chat")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Real-time chat with guild members while analyzing the chart")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
