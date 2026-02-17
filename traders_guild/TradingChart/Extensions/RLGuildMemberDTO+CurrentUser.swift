//
//  RLGuildMemberDTO+CurrentUser.swift
//  traders_guild
//
//  Helper to build a lightweight guild member for the current user.
//

import Foundation

extension RLGuildMemberDTO {
    static func fromCurrentUser(user: RLUserDTO, membership: RLGuildMembershipDTO) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: membership.id,
            role: membership.role,
            reputation: membership.reputation,
            contributionScore: membership.contributionScore,
            dateJoined: membership.dateJoined,
            accuracyRate: nil,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            isOnline: user.isOnline,
            globalReputation: user.globalReputation,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }
}
