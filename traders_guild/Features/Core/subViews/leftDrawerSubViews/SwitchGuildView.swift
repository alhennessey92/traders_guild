//
//  SwitchGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI

struct SwitchGuildView: View {
    let onBack: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 20)
            .padding(.horizontal)
            
            Text("Switch Guild")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
                .padding(.horizontal)
            
            // Guild list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        GuildSwitchRow(guildName: "Guild \(index + 1)")
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}





struct GuildSwitchRow: View {
    let guildName: String
    
    var body: some View {
        Button(action: {
            // Handle guild selection
        }) {
            HStack(spacing: 12) {
                Image(systemName: "shield.pattern.checkered")
                    .font(.title3)
                    .foregroundColor(AppColors.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(guildName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("\(Int.random(in: 10...100)) members")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }
}
