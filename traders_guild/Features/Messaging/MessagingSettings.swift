//
//  MessagingSettings.swift
//  traders_guild
//
//  Created by Al Hennessey on 02/11/2025.
//

import SwiftUI

// MARK: - Settings Components
/// Settings section header — delegates to UnifiedSectionHeader for design-system consistency.
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        UnifiedSectionHeader(title: title)
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .padding(.bottom, 12)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let iconColor: Color
    
    init(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>, iconColor: Color) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accentColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.insetPanelBackground)
        )
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, iconColor: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.whiteText.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColors.whiteText.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }
}

// MARK: - Mute Duration Helper
enum MuteDuration {
    case minutes15
    case hour1
    case hours8
    case hours24
    
    var displayName: String {
        switch self {
        case .minutes15: return "15 minutes"
        case .hour1: return "1 hour"
        case .hours8: return "8 hours"
        case .hours24: return "24 hours"
        }
    }
}
