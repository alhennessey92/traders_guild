//
//  StatisticsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 02/11/2025.
//
import SwiftUI

/// Statistics overview cards for the guild.
struct StatisticsView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    /// Guild reputation: sum of all members' reputation when members are loaded.
    private var guildReputationDisplay: String {
        if leftDrawerViewModel.guildMembers.isEmpty {
            return "--"
        }
        let total = leftDrawerViewModel.guildMembers.reduce(0) { $0 + $1.reputation }
        return "\(total)"
    }

    var body: some View {
        VStack(spacing: 12) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.statistics == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Guild Statistics...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            else {
                if let statistics = leftDrawerViewModel.statistics {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guild Performance")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .padding(.bottom, 4)
                        
                        StatRow(label: "Guild Reputation", value: guildReputationDisplay)
                        StatRow(label: "Total Predictions", value: statistics.totalPredictionsDisplay)
                        StatRow(label: "Correct Predictions", value: statistics.correctPredictionsDisplay)
                        StatRow(label: "Average Accuracy", value: statistics.averageAccuracyDisplay)
                        StatRow(label: "Guild Rank", value: statistics.guildRankDisplay)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This Week")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .padding(.bottom, 4)
                        
                        StatRow(label: "New Members", value: statistics.newMembersDisplay)
                        StatRow(label: "Active Users", value: statistics.activeUsersDisplay)
                        StatRow(label: "Predictions Made", value: statistics.predictionsMadeDisplay)
                        StatRow(label: "Reputation Earned", value: statistics.reputationEarnedDisplay)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("Top Contributors")
//                        .font(.headline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding(.bottom, 4)
//                    
//                    ForEach(1...5, id: \.self) { index in
//                        HStack {
//                            Text("\(index).")
//                                .font(.caption)
//                                .foregroundColor(AppColors.whiteText.opacity(0.5))
//                                .frame(width: 20)
//                            Text("User\(index)")
//                                .font(.subheadline)
//                                .foregroundColor(AppColors.whiteText)
//                            Spacer()
//                            Text("+\(200 - index * 30)")
//                                .font(.subheadline)
//                                .fontWeight(.semibold)
//                                .foregroundColor(AppColors.accentColor)
//                        }
//                    }
//                }
//                .padding()
//                .background(Color.white.opacity(0.08))
//                .cornerRadius(10)
                
            }
            
        }
        .padding(.horizontal, 16)
    }
}

/// One-line label/value row used in statistics cards.
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText)
        }
    }
}
