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
            StaticPatternView()
        }
        .ignoresSafeArea()
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
                .fill(AppColors.surfaceWhite05)
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
                .fill(AppColors.surfaceWhite03)
        )
    }
}

struct AdminFooterActions: View {
    let primaryTitle: String
    var primaryDisabled: Bool = false
    var isSubmitting: Bool = false
    let onCancel: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Cancel", action: onCancel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.greyText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppColors.surfaceWhite06)
                )

            Spacer()

            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.black)
                    }
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppColors.whiteText)
                )
            }
            .disabled(primaryDisabled || isSubmitting)
            .opacity((primaryDisabled || isSubmitting) ? 0.5 : 1.0)
        }
    }
}
