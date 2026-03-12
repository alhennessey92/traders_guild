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

                        BreakdownDateBarChart(
                            points: reputationTrendPoints(
                                from: profile.reputationTrend30d,
                                positiveTint: AppColors.accentColor
                            ),
                            centeredBaseline: true
                        )
                        .padding(.top, 10)
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

                        BreakdownDateBarChart(
                            points: accuracyTrendPoints(
                                from: profile.accuracyTrend30d,
                                tint: breakdownAccuracyColor(profile.accuracyRate)
                            ),
                            centeredBaseline: false
                        )
                        .padding(.top, 10)
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

                        BreakdownDateBarChart(
                            points: reputationTrendPoints(
                                from: profile.reputationTrend30d,
                                positiveTint: profile.tier.color
                            ),
                            centeredBaseline: true
                        )
                        .padding(.top, 10)
                    }

                    BreakdownCard(title: "Progress") {
                        if let nextTier = tiers.first(where: { $0.tierLevel == profile.tier.tierLevel + 1 }) {
                            let progress = Double(profile.reputation - profile.tier.minReputation) / Double(max(1, nextTier.minReputation - profile.tier.minReputation))
                            VStack(alignment: .leading, spacing: 8) {
                                BreakdownMetricRow(label: "To Tier \(nextTier.tierLevel)", value: "\(profile.reputation) / \(nextTier.minReputation)", valueColor: AppColors.whiteText)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppColors.surfaceWhite08)
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

                        BreakdownDateBarChart(
                            points: accuracyTrendPoints(
                                from: profile.accuracyTrend30d,
                                tint: breakdownAccuracyColor(profile.accuracyRate)
                            ),
                            centeredBaseline: false
                        )
                        .padding(.top, 10)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.surfaceWhite05)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 0.8)
                )
        )
    }
}

private struct BreakdownSheetBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
        }
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
                    Capsule().fill(AppColors.surfaceWhite08)
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct BreakdownDateBarPoint: Identifiable {
    let day: Date
    let value: Double
    let tint: Color

    var id: Date { day }
}

private struct BreakdownDateBarChart: View {
    let points: [BreakdownDateBarPoint]
    let centeredBaseline: Bool

    private var maxMagnitude: Double {
        max(points.map { abs($0.value) }.max() ?? 1, 1)
    }

    private var baselineAlignment: Alignment {
        centeredBaseline ? .center : .bottom
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                if points.isEmpty {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.surfaceWhite04)
                        .overlay(
                            Text("No 30-day trend data")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        )
                } else {
                    ZStack(alignment: baselineAlignment) {
                        if centeredBaseline {
                            Rectangle()
                                .fill(AppColors.surfaceWhite12)
                                .frame(height: 1)
                        }

                        HStack(alignment: centeredBaseline ? .center : .bottom, spacing: 2) {
                            ForEach(points) { point in
                                let ratio = max(0.05, min(1, abs(point.value) / maxMagnitude))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(point.tint)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: (geometry.size.height - 4) * ratio)
                                    .offset(y: centeredBaseline ? (point.value >= 0 ? -(geometry.size.height * 0.25 * ratio) : geometry.size.height * 0.25 * ratio) : 0)
                            }
                        }
                    }
                }
            }
            .frame(height: 64)

            HStack {
                Text(dateLabel(for: points.first?.day))
                Spacer()
                Text(dateLabel(for: points.dropFirst(points.count / 2).first?.day))
                Spacer()
                Text(dateLabel(for: points.last?.day))
            }
            .font(.caption2)
            .foregroundColor(AppColors.greyText.opacity(0.85))
        }
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private func reputationTrendPoints(
    from trend: [RLReputationTrendPointDTO],
    positiveTint: Color
) -> [BreakdownDateBarPoint] {
    trend.map { point in
        BreakdownDateBarPoint(
            day: point.day,
            value: Double(point.value),
            tint: point.value >= 0 ? positiveTint : AppColors.statusNegative82
        )
    }
}

private func accuracyTrendPoints(
    from trend: [RLAccuracyTrendPointDTO],
    tint: Color
) -> [BreakdownDateBarPoint] {
    var previous: Double?
    return trend.map { point in
        let value = point.value
        let direction: Color
        if let previous {
            if value > previous + 0.0001 {
                direction = .green
            } else if value + 0.0001 < previous {
                direction = .red
            } else {
                direction = tint.opacity(0.6)
            }
        } else {
            direction = tint
        }
        previous = value
        return BreakdownDateBarPoint(
            day: point.day,
            value: value,
            tint: direction
        )
    }
}

private func breakdownAccuracyColor(_ value: Double) -> Color {
    if value >= 0.7 { return .green }
    if value >= 0.5 { return .yellow }
    if value >= 0.3 { return .orange }
    return .red
}
