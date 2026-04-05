//
//  UserRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//  Conforms to unified components: username · role · reputation · accuracy (with profile chevron).
//

import SwiftUI

// MARK: - User Row View button for left drawer (unified style with reputation + accuracy)
struct UserRowView: View {
    let user: RLUserDTO
    let membership: RLGuildMembershipDTO
    let onTap: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @State private var isPressed = false

    private var member: RLGuildMemberDTO {
        RLGuildMemberDTO.fromCurrentUser(user: user, membership: membership)
    }

    private var isOnline: Bool {
        rlAppState.effectiveOnlineStatus(userId: user.id, fallback: user.isOnline)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                UnifiedMemberAvatar(
                    username: user.username,
                    avatarURL: user.avatarUrl,
                    isOnline: isOnline,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayUsername)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)

                    UnifiedRoleBadge(member: member, showReputation: true)
                }

                Spacer()

                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPressed ? AppColors.userListRowFillPressed : AppColors.userListRowFill)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
