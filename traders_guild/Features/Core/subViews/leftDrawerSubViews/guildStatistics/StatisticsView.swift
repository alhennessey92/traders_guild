//
//  StatisticsView.swift
//  traders_guild
//
//  Grafana-style guild statistics dashboard. Same 14 metrics as the previous
//  text-row layout, restructured into a KPI band + Prediction Quality (gauge
//  + donut) + Weekly Momentum (KPI tiles with sparklines) + Derived
//  Efficiency (progress bars) + 30-day Trends (bar/line charts).
//
import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    private var guildMemberCount: Int {
        leftDrawerViewModel.guildMembers.count
    }

    private var guildReputationTotal: Int {
        leftDrawerViewModel.guildMembers.reduce(0) { $0 + $1.reputation }
    }

    private var historyPoints: [RLGuildStatisticsHistoryPoint] {
        leftDrawerViewModel.statisticsHistory?.points ?? []
    }

    var body: some View {
        VStack(spacing: 12) {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.statistics == nil {
                loadingState
            } else if let statistics = leftDrawerViewModel.statistics {
                kpiBand(statistics: statistics)
                predictionQualityCard(statistics: statistics)
                weeklyMomentumCard(statistics: statistics)
                derivedEfficiencyCard(statistics: statistics)
                trendsCard()
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Loading / Section Header

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading Guild Statistics...")
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - KPI Band (Snapshot)

    private func kpiBand(statistics: RLGuildStatisticsResponse) -> some View {
        HStack(spacing: 10) {
            StatKPITile(
                label: "Guild Rank",
                value: statistics.guildRankDisplay,
                tint: AppColors.statisticsMetricYellow,
                compact: true
            )
            StatKPITile(
                label: "Members",
                value: "\(guildMemberCount)",
                tint: AppColors.whiteText,
                compact: true
            )
            StatKPITile(
                label: "Total Rep",
                value: MetricFormat.exactInt(guildReputationTotal),
                tint: AppColors.accentColor,
                compact: true
            )
        }
    }

    // MARK: - Prediction Quality (gauge + donut + KPI rows)

    private func predictionQualityCard(statistics: RLGuildStatisticsResponse) -> some View {
        let losses = max(0, statistics.totalPredictions - statistics.correctPredictions)
        let accuracy = statistics.averageAccuracy
        let accuracyTint = MetricTint.accuracy(accuracy)

        return GuildStatsSectionCard(title: "Prediction Quality", subtitle: "Wins, losses and consistency") {
            HStack(alignment: .center, spacing: 14) {
                StatGauge(
                    progress: accuracy,
                    centerText: statistics.averageAccuracyDisplay,
                    captionText: "ACCURACY",
                    tint: accuracyTint,
                    size: 92,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 6) {
                    LegendRow(label: "Wins", value: MetricFormat.compactInt(statistics.correctPredictions), tint: AppColors.statusPositive)
                    LegendRow(label: "Losses", value: MetricFormat.compactInt(losses), tint: AppColors.statusNegative)
                    LegendRow(label: "Total", value: statistics.totalPredictionsDisplay, tint: AppColors.whiteText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatDonut(
                    slices: [
                        StatDonutSlice(label: "Wins", value: Double(statistics.correctPredictions), tint: AppColors.statusPositive),
                        StatDonutSlice(label: "Losses", value: Double(losses), tint: AppColors.statusNegative)
                    ],
                    centerText: statistics.averageAccuracyDisplay,
                    centerCaption: "Hit Rate",
                    size: 92
                )
            }
        }
    }

    // MARK: - Weekly Momentum (KPI tiles + sparklines)

    private func weeklyMomentumCard(statistics: RLGuildStatisticsResponse) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return GuildStatsSectionCard(title: "Weekly Momentum", subtitle: "Most recent guild movement") {
            LazyVGrid(columns: columns, spacing: 10) {
                StatKPITile(
                    label: "New Members",
                    value: statistics.newMembersDisplay,
                    tint: AppColors.statisticsMetricMint,
                    sparkline: sparklineSeries(\.newMembers),
                    sparklineTint: AppColors.statisticsMetricMint
                )
                StatKPITile(
                    label: "Active Users",
                    value: statistics.activeUsersDisplay,
                    tint: AppColors.statusInfo,
                    sparkline: sparklineSeries(\.activeMembers),
                    sparklineTint: AppColors.statusInfo
                )
                StatKPITile(
                    label: "Predictions",
                    value: statistics.predictionsMadeDisplay,
                    tint: AppColors.statisticsMetricYellow,
                    sparkline: sparklineSeries(\.predictionsMade),
                    sparklineTint: AppColors.statisticsMetricYellow
                )
                StatKPITile(
                    label: "Rep Earned",
                    value: statistics.reputationEarnedDisplay,
                    tint: statistics.reputationEarnedWeek >= 0 ? AppColors.statusPositive : AppColors.statusNegative,
                    sparkline: sparklineSeries(\.reputationEarned),
                    sparklineTint: statistics.reputationEarnedWeek >= 0 ? AppColors.statusPositive : AppColors.statusNegative
                )
            }
        }
    }

    // MARK: - Derived Efficiency (progress bars)

    private func derivedEfficiencyCard(statistics: RLGuildStatisticsResponse) -> some View {
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

        // Progress bars need [0,1] inputs. Rep/Prediction and Predictions/User are unbounded
        // so we soft-clamp by their target (8 rep per pred and 5 preds per user respectively),
        // which gives a useful "how close to a high-engagement guild" feel.
        let repPerPredictionProgress = min(1, max(0, repPerPrediction / 8))
        let predictionsPerUserProgress = min(1, max(0, predictionsPerActiveUser / 5))

        return GuildStatsSectionCard(title: "Derived Efficiency", subtitle: "Calculated from existing data") {
            VStack(spacing: 12) {
                StatProgressBar(
                    label: "Rep / Prediction",
                    valueText: String(format: "%.2f", repPerPrediction),
                    progress: repPerPredictionProgress,
                    tint: AppColors.accentColor
                )
                StatProgressBar(
                    label: "Participation",
                    valueText: MetricFormat.percent(participationRatio),
                    progress: participationRatio,
                    tint: AppColors.statusInfo
                )
                StatProgressBar(
                    label: "Hit Rate",
                    valueText: MetricFormat.percent(hitRate),
                    progress: hitRate,
                    tint: MetricTint.accuracy(hitRate)
                )
                StatProgressBar(
                    label: "Predictions / Active User",
                    valueText: String(format: "%.2f", predictionsPerActiveUser),
                    progress: predictionsPerUserProgress,
                    tint: AppColors.statisticsMetricOrange
                )
            }
        }
    }

    // MARK: - 30-Day Trends

    private func trendsCard() -> some View {
        GuildStatsSectionCard(title: "30-Day Trends", subtitle: "Daily aggregates from the guild") {
            if leftDrawerViewModel.isLoadingStatisticsHistory && historyPoints.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.9)
                    Spacer()
                }
                .frame(height: 64)
            } else if historyPoints.isEmpty {
                Text("Trend data unavailable")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 14) {
                    trendSection(
                        title: "Reputation",
                        view: AnyView(
                            StatTrendBars(
                                points: historyPoints.map { point in
                                    StatTrendBarPoint(
                                        day: point.day,
                                        value: Double(point.reputationEarned),
                                        tint: point.reputationEarned >= 0 ? AppColors.statusPositive : AppColors.statusNegative
                                    )
                                },
                                centeredBaseline: true
                            )
                        )
                    )

                    trendSection(
                        title: "Accuracy",
                        view: AnyView(accuracyLineChart)
                    )

                    trendSection(
                        title: "Predictions",
                        view: AnyView(
                            StatTrendBars(
                                points: historyPoints.map { point in
                                    StatTrendBarPoint(
                                        day: point.day,
                                        value: Double(point.predictionsMade),
                                        tint: AppColors.statisticsMetricYellow
                                    )
                                },
                                centeredBaseline: false
                            )
                        )
                    )
                }
            }
        }
    }

    private var accuracyLineChart: some View {
        let points = historyPoints.map { point -> AccuracyLineEntry in
            AccuracyLineEntry(day: point.day, value: point.accuracy)
        }
        return VStack(spacing: 6) {
            Chart(points) { entry in
                AreaMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Accuracy", entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.statusPositive.opacity(0.4), AppColors.statusPositive.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Accuracy", entry.value)
                )
                .foregroundStyle(AppColors.statusPositive)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...1)
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

    private func trendSection(title: String, view: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText.opacity(0.85))
            view
        }
    }

    // MARK: - Helpers

    private func sparklineSeries(_ keyPath: KeyPath<RLGuildStatisticsHistoryPoint, Int>) -> [Double] {
        historyPoints.map { Double($0[keyPath: keyPath]) }
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private struct AccuracyLineEntry: Identifiable {
    let day: Date
    let value: Double
    var id: Date { day }
}

private struct LegendRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.whiteText.opacity(0.7))
            Spacer(minLength: 4)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(tint)
        }
    }
}

private struct GuildStatsSectionCard<Content: View>: View {
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
