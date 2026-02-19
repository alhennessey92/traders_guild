import SwiftUI

struct GlobalReputationBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLGlobalReputationDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.accentColor).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Global Reputation")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.globalReputation)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppColors.whiteText)
                                Text("Tier \(profile.tier.tierLevel)")
                                    .font(.caption)
                                    .foregroundColor(profile.tier.color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("Weekly")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.weeklyDelta >= 0 ? "+" : "")\(profile.weeklyDelta)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(profile.weeklyDelta >= 0 ? .green : .red)
                            }
                        }

                        BreakdownMiniChart(
                            values: profile.guildContributions.map { Double(max(0, $0.reputation)) },
                            tint: AppColors.accentColor
                        )
                        .padding(.top, 8)
                    }

                    BreakdownCard(title: "Guild Contributions") {
                        if profile.guildContributions.isEmpty {
                            Text("No contribution data yet")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(profile.guildContributions, id: \.guildId) { guild in
                                    BreakdownBarRow(
                                        label: guild.guildName,
                                        valueText: "\(guild.reputation)",
                                        progress: max(0, min(1, Double(guild.reputation) / Double(max(1, profile.globalReputation)))),
                                        tint: AppColors.accentColor
                                    )
                                }
                            }
                        }
                    }

                    BreakdownCard(title: "Modifiers") {
                        VStack(spacing: 10) {
                            BreakdownMetricRow(label: "Total Modifier", value: profile.modifiers.totalModifierFormatted, valueColor: AppColors.accentColor)
                            BreakdownMetricRow(label: "Clean Record", value: profile.modifiers.cleanRecordBonus ? "Yes" : "No", valueColor: profile.modifiers.cleanRecordBonus ? .green : .red)
                            BreakdownMetricRow(label: "Consecutive Active Days", value: "\(profile.consecutiveActiveDays)", valueColor: AppColors.whiteText)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profile = try await rlAppState.realApi.getMyGlobalReputation()
        } catch {
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct GlobalAccuracyBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLAccuracyProfileDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.accentColor).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        VStack(spacing: 8) {
                            Text(profile.accuracyDetailedFormatted)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(breakdownAccuracyColor(profile.accuracyRate))
                            Text("Global Accuracy")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(profile.recordFormatted)
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                        }
                        .frame(maxWidth: .infinity)

                        BreakdownMiniChart(
                            values: [
                                Double(profile.successfulPredictions),
                                Double(max(0, profile.totalPredictions - profile.successfulPredictions))
                            ],
                            tint: breakdownAccuracyColor(profile.accuracyRate)
                        )
                        .padding(.top, 8)
                    }

                    BreakdownCard(title: "Performance") {
                        VStack(spacing: 10) {
                            BreakdownMetricRow(label: "Predictions", value: "\(profile.totalPredictions)", valueColor: AppColors.whiteText)
                            BreakdownMetricRow(label: "Wins", value: "\(profile.successfulPredictions)", valueColor: .green)
                            BreakdownMetricRow(label: "Losses", value: "\(max(0, profile.totalPredictions - profile.successfulPredictions))", valueColor: .red)
                            BreakdownMetricRow(label: "Avg R:R", value: profile.rrRatioFormatted ?? "--", valueColor: .orange)
                        }
                    }

                    BreakdownCard(title: "Streaks") {
                        HStack(spacing: 8) {
                            BreakdownMetricPill(label: "Win", value: "\(profile.winStreak)", tint: .green)
                            BreakdownMetricPill(label: "Loss", value: "\(profile.lossStreak)", tint: .red)
                            BreakdownMetricPill(label: "Best", value: "\(profile.bestWinStreak)", tint: .yellow)
                        }
                    }

                    if let rollingAccuracy = profile.rollingAccuracyFormatted {
                        BreakdownCard(title: "30-Day Rolling") {
                            HStack(spacing: 12) {
                                BreakdownMetricPill(label: "Accuracy", value: rollingAccuracy, tint: AppColors.accentColor)
                                BreakdownMetricPill(label: "Wins", value: "\(profile.rollingWins30d)", tint: .green)
                                BreakdownMetricPill(
                                    label: "Losses",
                                    value: "\(max(0, profile.rollingTotal30d - profile.rollingWins30d))",
                                    tint: .red
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profile = try await rlAppState.realApi.getMyGlobalAccuracy()
        } catch {
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct GuildReputationBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLReputationProfileDTO?
    @State private var tiers: [RLReputationTierDTO] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.accentColor).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Guild Reputation")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                Text("\(profile.reputation)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppColors.whiteText)
                                Text("Tier \(profile.tier.tierLevel)")
                                    .font(.caption)
                                    .foregroundColor(profile.tier.color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                if profile.rankInGuild > 0 {
                                    Text("Rank #\(profile.rankInGuild)")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.whiteText)
                                }
                                Text("\(profile.weeklyDelta >= 0 ? "+" : "")\(profile.weeklyDelta) this week")
                                    .font(.caption)
                                    .foregroundColor(profile.weeklyDelta >= 0 ? .green : .red)
                            }
                        }

                        BreakdownMiniChart(
                            values: [
                                Double(max(0, profile.breakdown.socialRep)),
                                Double(max(0, profile.breakdown.activityRep)),
                                Double(abs(min(0, profile.breakdown.penaltyRep)))
                            ],
                            tint: profile.tier.color
                        )
                        .padding(.top, 8)
                    }

                    BreakdownCard(title: "Progress") {
                        if let nextTier = tiers.first(where: { $0.tierLevel == profile.tier.tierLevel + 1 }) {
                            let progress = Double(profile.reputation - profile.tier.minReputation) / Double(max(1, nextTier.minReputation - profile.tier.minReputation))
                            VStack(alignment: .leading, spacing: 8) {
                                BreakdownMetricRow(label: "To Tier \(nextTier.tierLevel)", value: "\(profile.reputation) / \(nextTier.minReputation)", valueColor: AppColors.whiteText)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.08))
                                        Capsule().fill(profile.tier.color)
                                            .frame(width: geometry.size.width * max(0, min(1, progress)))
                                    }
                                }
                                .frame(height: 8)
                            }
                        } else {
                            Text("Maximum tier reached")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }

                    BreakdownCard(title: "Breakdown") {
                        VStack(spacing: 10) {
                            BreakdownBarRow(label: "Social", valueText: "\(profile.breakdown.socialRep)", progress: fraction(value: profile.breakdown.socialRep, total: profile.breakdown.total), tint: .blue)
                            BreakdownBarRow(label: "Activity", valueText: "\(profile.breakdown.activityRep)", progress: fraction(value: profile.breakdown.activityRep, total: profile.breakdown.total), tint: .cyan)
                            if profile.breakdown.penaltyRep != 0 {
                                BreakdownBarRow(label: "Penalties", valueText: "\(profile.breakdown.penaltyRep)", progress: fraction(value: abs(profile.breakdown.penaltyRep), total: max(1, abs(profile.breakdown.total))), tint: .red)
                            }
                        }
                    }

                    BreakdownCard(title: "Limits") {
                        BreakdownMetricRow(label: "Daily Social Cap Remaining", value: "\(Int(profile.dailySocialCapRemaining))", valueColor: AppColors.whiteText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            errorMessage = "No guild selected"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileTask = rlAppState.realApi.getMyGuildReputation(guildId: guildId)
            async let tiersTask = rlAppState.realApi.getReputationTiers()
            let (loadedProfile, loadedTiers) = try await (profileTask, tiersTask)
            profile = loadedProfile
            tiers = loadedTiers
        } catch {
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }

    private func fraction(value: Int, total: Int) -> Double {
        guard total != 0 else { return 0 }
        return max(0, min(1, Double(abs(value)) / Double(abs(total))))
    }
}

struct GuildAccuracyBreakdownSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profile: RLAccuracyProfileDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView().tint(AppColors.accentColor).padding(.top, 36)
                } else if let errorMessage {
                    UnifiedEmptyState(icon: "exclamationmark.triangle", title: "Unable to load", subtitle: errorMessage)
                        .padding(.top, 28)
                } else if let profile {
                    BreakdownCard {
                        VStack(spacing: 8) {
                            Text(profile.accuracyDetailedFormatted)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(breakdownAccuracyColor(profile.accuracyRate))
                            Text("Guild Accuracy")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(profile.recordFormatted)
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                        }
                        .frame(maxWidth: .infinity)

                        BreakdownMiniChart(
                            values: [
                                Double(profile.successfulPredictions),
                                Double(max(0, profile.totalPredictions - profile.successfulPredictions)),
                                Double(profile.bestWinStreak)
                            ],
                            tint: breakdownAccuracyColor(profile.accuracyRate)
                        )
                        .padding(.top, 8)
                    }

                    BreakdownCard(title: "Performance") {
                        VStack(spacing: 10) {
                            BreakdownMetricRow(label: "Predictions", value: "\(profile.totalPredictions)", valueColor: AppColors.whiteText)
                            BreakdownMetricRow(label: "Wins", value: "\(profile.successfulPredictions)", valueColor: .green)
                            BreakdownMetricRow(label: "Losses", value: "\(max(0, profile.totalPredictions - profile.successfulPredictions))", valueColor: .red)
                            BreakdownMetricRow(label: "Avg R:R", value: profile.rrRatioFormatted ?? "--", valueColor: .orange)
                            if let rank = profile.rankInGuild {
                                BreakdownMetricRow(label: "Rank in Guild", value: "#\(rank)", valueColor: AppColors.accentColor)
                            }
                        }
                    }

                    BreakdownCard(title: "Streaks") {
                        HStack(spacing: 8) {
                            BreakdownMetricPill(label: "Win", value: "\(profile.winStreak)", tint: .green)
                            BreakdownMetricPill(label: "Loss", value: "\(profile.lossStreak)", tint: .red)
                            BreakdownMetricPill(label: "Best", value: "\(profile.bestWinStreak)", tint: .yellow)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(BreakdownSheetBackground())
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            errorMessage = "No guild selected"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profile = try await rlAppState.realApi.getMyGuildAccuracy(guildId: guildId)
        } catch {
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct BreakdownCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct BreakdownSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppColors.gradientBackgroundDark.opacity(0.55),
                AppColors.sheetBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct BreakdownMetricRow: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

private struct BreakdownMetricPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct BreakdownBarRow: View {
    let label: String
    let valueText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                Text(valueText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(tint)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct BreakdownMiniChart: View {
    let values: [Double]
    let tint: Color

    private var normalized: [Double] {
        let maxValue = max(values.max() ?? 1, 1)
        return values.map { max(0.12, min(1, $0 / maxValue)) }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(normalized.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 44 * value)
            }
        }
        .frame(height: 48, alignment: .bottom)
    }
}

private func breakdownAccuracyColor(_ value: Double) -> Color {
    if value >= 0.7 { return .green }
    if value >= 0.5 { return .yellow }
    if value >= 0.3 { return .orange }
    return .red
}
