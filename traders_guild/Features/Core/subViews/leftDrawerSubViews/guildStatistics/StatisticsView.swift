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

    private var guildMemberCount: Int {
        leftDrawerViewModel.guildMembers.count
    }

    private var guildReputationTotal: Int {
        leftDrawerViewModel.guildMembers.reduce(0) { $0 + $1.reputation }
    }

    var body: some View {
        VStack(spacing: 12) {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.statistics == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Guild Statistics...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let statistics = leftDrawerViewModel.statistics {
                GuildStatsCard(title: "Snapshot", subtitle: "Guild rank and totals") {
                    StatMetricRow(label: "Guild Reputation", value: formatInt(guildReputationTotal), accent: AppColors.accentColor)
                    StatMetricRow(label: "Guild Rank", value: statistics.guildRankDisplay, accent: AppColors.statisticsMetricYellow)
                    StatMetricRow(label: "Total Predictions", value: statistics.totalPredictionsDisplay, accent: AppColors.whiteText)
                    StatMetricRow(label: "Member Count", value: "\(guildMemberCount)", accent: AppColors.whiteText)
                }

                GuildStatsCard(title: "Prediction Quality", subtitle: "Wins, losses and consistency") {
                    let losses = max(0, statistics.totalPredictions - statistics.correctPredictions)
                    let errorRate = statistics.totalPredictions > 0
                        ? Double(losses) / Double(statistics.totalPredictions)
                        : 0

                    StatMetricRow(label: "Wins", value: formatInt(statistics.correctPredictions), accent: AppColors.statisticsMetricGreen)
                    StatMetricRow(label: "Losses", value: formatInt(losses), accent: .red)
                    StatMetricRow(label: "Accuracy", value: statistics.averageAccuracyDisplay, accent: accuracyTint(statistics.averageAccuracy))
                    StatMetricRow(label: "Error Rate", value: percent(errorRate), accent: AppColors.statisticsMetricOrange)
                }

                GuildStatsCard(title: "Weekly Momentum", subtitle: "Most recent guild movement") {
                    StatMetricRow(label: "New Members", value: statistics.newMembersDisplay, accent: AppColors.statisticsMetricMint)
                    StatMetricRow(label: "Active Users", value: statistics.activeUsersDisplay, accent: .blue)
                    StatMetricRow(label: "Predictions", value: statistics.predictionsMadeDisplay, accent: .purple)
                    StatMetricRow(
                        label: "Rep Earned",
                        value: statistics.reputationEarnedDisplay,
                        accent: statistics.reputationEarnedWeek >= 0 ? AppColors.statisticsMetricGreen : AppColors.statusNegative
                    )
                }

                GuildStatsCard(title: "Derived Efficiency", subtitle: "Calculated from existing data") {
                    let repPerPrediction = statistics.predictionsWeek > 0
                        ? Double(statistics.reputationEarnedWeek) / Double(statistics.predictionsWeek)
                        : 0
                    let participationRatio = guildMemberCount > 0
                        ? Double(statistics.activeMembersWeek) / Double(guildMemberCount)
                        : 0
                    let hitRate = statistics.totalPredictions > 0
                        ? Double(statistics.correctPredictions) / Double(statistics.totalPredictions)
                        : 0
                    let predictionsPerActiveUser = statistics.activeMembersWeek > 0
                        ? Double(statistics.predictionsWeek) / Double(statistics.activeMembersWeek)
                        : 0

                    StatMetricRow(label: "Rep / Prediction", value: String(format: "%.2f", repPerPrediction), accent: AppColors.accentColor)
                    StatMetricRow(label: "Participation", value: percent(participationRatio), accent: .blue)
                    StatMetricRow(label: "Hit Rate", value: percent(hitRate), accent: accuracyTint(hitRate))
                    StatMetricRow(
                        label: "Predictions / Active User",
                        value: String(format: "%.2f", predictionsPerActiveUser),
                        accent: AppColors.statisticsMetricOrange
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func accuracyTint(_ accuracy: Double) -> Color {
        if accuracy >= 0.7 { return AppColors.statisticsMetricGreen }
        if accuracy >= 0.5 { return AppColors.statisticsMetricYellow }
        if accuracy >= 0.35 { return AppColors.statisticsMetricOrange }
        return AppColors.statusNegative
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func formatInt(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

private struct GuildStatsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.guildStatisticsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.guildStatisticsCardStroke, lineWidth: 1)
                )
        )
    }
}

private struct StatMetricRow: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.75))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(accent)
        }
    }
}
