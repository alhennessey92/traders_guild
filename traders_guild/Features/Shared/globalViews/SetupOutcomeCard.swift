//
//  SetupOutcomeCard.swift
//  traders_guild
//
//  Unified "result-led" card for a resolved setup outcome (TP Hit / SL Hit / Expired).
//
//  Single source of truth that replaces the three previously hand-rolled outcome
//  renderers — MarkerViewingInfoBox.resolvedSetupSummary, MarkerViewingGeneralTab
//  .outcomeResultCard, and MarkerDetailView.setupOutcomeSection — so the SL/TP-hit
//  view reads identically across the on-chart info box, the drawer tab, and the
//  full detail view. Sits beside UnifiedSetupProgressStrip / TrackingStatePill.
//

import SwiftUI

/// Size variant for the unified setup-outcome card.
enum SetupOutcomeCardSize {
    /// On-chart info box — width constrained (~220–244pt), tightest spacing.
    case compact
    /// Marker viewing drawer tab.
    case standard
    /// Full-screen marker detail view — largest hero, includes impact note.
    case detail
}

struct SetupOutcomeCard: View {
    let outcome: SetupOutcome
    var size: SetupOutcomeCardSize = .standard
    /// Pre-formatted risk:reward string, e.g. "R:R 2.4" (call site computes from prices).
    var riskRewardText: String? = nil
    /// Price formatter for the trigger price; falls back to 5dp if absent.
    var formatPrice: ((Double) -> String)? = nil

    // MARK: - Derived styling

    /// Win = TP green, Loss = SL red, Expired = neutral grey.
    private var tint: Color {
        if outcome.isWin { return RLComponentType.levelTp.color }
        if outcome.isLoss { return RLComponentType.levelSl.color }
        return AppColors.secondaryForeground
    }

    private var pnlText: String? {
        guard let pnl = outcome.pnl else { return nil }
        return pnl >= 0 ? String(format: "+%.2f%%", pnl) : String(format: "%.2f%%", pnl)
    }

    private var pnlColor: Color {
        guard let pnl = outcome.pnl else { return AppColors.primaryForeground }
        return pnl >= 0 ? RLComponentType.levelTp.color : RLComponentType.levelSl.color
    }

    private var triggerChipText: String? {
        guard let trigger = outcome.triggerPrice else { return nil }
        let priceStr = formatPrice?(trigger) ?? String(format: "%.5f", trigger)
        return "Hit @ \(priceStr)"
    }

    private var repTint: Color {
        (outcome.guildRepDelta ?? 0) >= 0 ? tint : RLComponentType.levelSl.color
    }

    // MARK: - Sizing tokens

    private var iconSize: CGFloat { size == .compact ? 15 : (size == .standard ? 19 : 22) }
    private var labelSize: CGFloat { size == .compact ? 12 : (size == .standard ? 14 : 15) }
    private var pnlSize: CGFloat { size == .compact ? 14 : (size == .standard ? 19 : 22) }
    private var contentSpacing: CGFloat { size == .compact ? 7 : 10 }
    private var cardPadding: CGFloat { size == .compact ? 10 : 14 }
    private var cornerRadius: CGFloat { size == .compact ? 11 : 13 }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            heroRow

            if hasSecondaryChips {
                secondaryChips
            }

            if size == .detail, let note = outcome.impactNote {
                impactRow(note)
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tint.opacity(0.34), lineWidth: 1)
                )
        )
    }

    // MARK: - Hero row (icon · label · P&L)

    private var heroRow: some View {
        HStack(spacing: size == .compact ? 8 : 10) {
            Image(systemName: outcome.displayIcon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(outcome.displayLabel.uppercased())
                    .font(.system(size: labelSize, weight: .heavy))
                    .foregroundColor(AppColors.primaryForeground)
                if size != .compact, let resolvedAt = outcome.triggeredAtFormatted {
                    Text(resolvedAt)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let pnlText {
                Text(pnlText)
                    .font(.system(size: pnlSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(pnlColor)
            }
        }
    }

    // MARK: - Secondary chips (R:R · Rep · Hit price)

    private var hasSecondaryChips: Bool {
        riskRewardText != nil || outcome.repChangeText != nil || triggerChipText != nil
    }

    private var secondaryChips: some View {
        FlowLayout(spacing: 6) {
            if let riskRewardText {
                chip(riskRewardText, tint: AppColors.surfaceWhite70)
            }
            if let repText = outcome.repChangeText {
                chip("Rep \(repText)", tint: repTint)
            }
            if let triggerChipText {
                chip(triggerChipText, tint: AppColors.surfaceWhite70)
            }
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: size == .compact ? 9.5 : 10.5, weight: .bold, design: .monospaced))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.whiteText.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    // MARK: - Impact note (detail only)

    private func impactRow(_ note: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: outcome.affectsPerformance ? "chart.line.uptrend.xyaxis" : "clock.badge.xmark")
                .font(.system(size: 10, weight: .semibold))
            Text(note)
                .font(.system(size: 11, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(
            outcome.affectsPerformance
                ? (outcome.isWin ? tint : RLComponentType.levelSl.color)
                : AppColors.greyText
        )
    }
}
