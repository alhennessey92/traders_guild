//
//  AdminSharedComponents.swift
//  traders_guild
//
//  Shared admin/owner sheet UI components.
//

import SwiftUI

struct AdminSheetBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            StaticPatternView(targetOpacity: AppColors.adminSheetPatternOpacity)
        }
        .ignoresSafeArea()
    }
}

private struct AdminSheetChrome: View {
    let edge: VerticalEdge

    var body: some View {
        Rectangle()
            .fill(AppColors.sheetBackground.opacity(0.98))
            .background(.ultraThinMaterial)
            .overlay(divider, alignment: edge == .top ? .bottom : .top)
            .overlay(gradient)
            .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.surfaceWhite12)
            .frame(height: 1)
    }

    private var gradient: some View {
        LinearGradient(
            colors: [
                AppColors.surfaceWhite06,
                AppColors.surfaceWhite00
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
    }
}

extension View {
    func adminSheetChrome(edge: VerticalEdge) -> some View {
        background(AdminSheetChrome(edge: edge))
    }
}

struct AdminSheetHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            UnifiedIconBadge(
                icon: icon,
                color: iconColor,
                size: 44,
                iconSize: 20,
                backgroundOpacity: 0.2
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
    }
}

struct AdminSectionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 0.8)
                )
        )
    }
}

struct AdminInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.surfaceWhite15, lineWidth: 1)
                        )
                )
        }
    }
}

struct AdminInputTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                    .frame(minHeight: 110)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.surfaceWhite15, lineWidth: 1)
                    )
            )
        }
    }
}

struct AdminToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.insetPanelBackground)
        )
    }
}

struct AdminFooterActions: View {
    let primaryTitle: String
    var primaryDisabled: Bool = false
    var isSubmitting: Bool = false
    var showsCancel: Bool = true
    var onCancel: (() -> Void)? = nil
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if showsCancel, let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.adminFooterCancelForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppColors.adminFooterCancelBackground)
                    )
            }

            Spacer()

            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(AppColors.adminFooterPrimaryForeground)
                    }
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(AppColors.adminFooterPrimaryForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppColors.adminFooterPrimaryBackground)
                )
            }
            .disabled(primaryDisabled || isSubmitting)
            .opacity((primaryDisabled || isSubmitting) ? 0.5 : 1.0)
        }
    }
}

struct AdminBottomActionBar: View {
    let primaryTitle: String
    var primaryDisabled: Bool = false
    var isSubmitting: Bool = false
    var showsCancel: Bool = true
    var onCancel: (() -> Void)? = nil
    let onPrimary: () -> Void

    var body: some View {
        AdminFooterActions(
            primaryTitle: primaryTitle,
            primaryDisabled: primaryDisabled,
            isSubmitting: isSubmitting,
            showsCancel: showsCancel,
            onCancel: onCancel,
            onPrimary: onPrimary
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .adminSheetChrome(edge: .bottom)
    }
}

struct AdminSheetFooterBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground.opacity(0.98)
        }
    }
}
