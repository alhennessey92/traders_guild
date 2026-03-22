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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.15))
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accentColor)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .padding(.horizontal, 12)
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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(iconColor.opacity(0.15))
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .padding(.horizontal, 12)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
