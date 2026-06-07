//
//  RLUserFacingMessage.swift
//  traders_guild
//
//  Centralized user-facing copy and error sanitization for production-safe UI messaging.
//

import Foundation

enum RLUserMessageKey: String {
    case actionOk = "message.action.ok"
    case errorTitle = "message.error.title"
    case warningTitle = "message.warning.title"
    case successTitle = "message.success.title"
    case infoTitle = "message.info.title"

    case errorGeneric = "message.error.generic"
    case errorNetwork = "message.error.network"
    case errorUnauthorized = "message.error.unauthorized"
    case errorAuthInvalidCredentials = "message.error.auth.invalid_credentials"
    case errorAppleSignInInvalid = "message.error.auth.apple_invalid"
    case errorPasswordResetInvalidCode = "message.error.auth.password_reset_invalid_code"
    case errorCurrentPasswordIncorrect = "message.error.auth.current_password_incorrect"
    case errorInvalidRequest = "message.error.invalid_request"
    case errorPermissionDenied = "message.error.permission_denied"
    case errorNotFound = "message.error.not_found"
    case errorConflict = "message.error.conflict"
    case errorRateLimited = "message.error.rate_limited"
    case errorServiceUnavailable = "message.error.service_unavailable"
    case errorDecode = "message.error.decode"
    case errorGuildApprovalRequired = "message.error.guild.approval_required"
    case errorGuildLimitReached = "message.error.guild.limit_reached"
    case errorGuildCooldown = "message.error.guild.rejoin_cooldown"
    case errorSetupConflict = "message.error.marker.setup_conflict"
    case errorSetupLimit = "message.error.marker.setup_limit"

    case infoPasswordResetRequestFailed = "message.info.password_reset_request_failed"
    case infoPasswordResetFailed = "message.info.password_reset_failed"
    case warningPushPreferencesLoadFailed = "message.warning.push_prefs.load_failed"
    case warningPushPreferencesSaveFailed = "message.warning.push_prefs.save_failed"
    case successCopiedToClipboard = "message.success.copied_to_clipboard"
    case successMessageDeleted = "message.success.message_deleted"
    case successMessageUpdated = "message.success.message_updated"
    case successReportSubmitted = "message.success.report_submitted"
    case errorNoGuildSelected = "message.error.no_guild_selected"
    case errorSelectGuildFirst = "message.error.select_guild_first"
    case errorNoChartDataSelection = "message.error.no_chart_data_selection"
    case errorCannotSendNoPermission = "message.error.cannot_send.no_permission"
    case errorCannotSendBlockedUser = "message.error.cannot_send.blocked_user"
    case successWelcomeUser = "message.success.welcome_user"
    case infoLoggedOut = "message.info.logged_out"
    case infoSignInAgain = "message.info.sign_in_again"
    case successJoinedGuildNamed = "message.success.joined_guild_named"
    case successCreatedGuildNamed = "message.success.created_guild_named"
    case successJoinRequestSubmitted = "message.success.join_request_submitted"
    case successJoinRequestApproved = "message.success.join_request_approved"
    case successJoinRequestDeclined = "message.success.join_request_declined"
    case successAnnouncementPosted = "message.success.announcement_posted"
    case successEventCreated = "message.success.event_created"
    case successGuildSettingsUpdated = "message.success.guild_settings_updated"
    case successInviteSent = "message.success.invite_sent"
    case successInviteCancelled = "message.success.invite_cancelled"
    case successJoinedGuild = "message.success.joined_guild"
    case successMemberBanned = "message.success.member_banned"
    case successMemberUnbanned = "message.success.member_unbanned"
    case successMemberKicked = "message.success.member_kicked"
    case successMemberMuted = "message.success.member_muted"
    case successMemberUnmuted = "message.success.member_unmuted"
    case successMemberSuspended = "message.success.member_suspended"
    case successMemberUnsuspended = "message.success.member_unsuspended"
    case successRoleUpdated = "message.success.role_updated"
    case successReportAction = "message.success.report_action"
    case successProfileUpdated = "message.success.profile_updated"
    case successAvatarUpdated = "message.success.avatar_updated"
    case successAvatarRemoved = "message.success.avatar_removed"
    case successVerificationEmailSent = "message.success.verification_email_sent"
    case successPasswordUpdated = "message.success.password_updated"
    case successDataExportRequested = "message.success.data_export_requested"
    case successSupportTicketSubmitted = "message.success.support_ticket_submitted"
    case successFriendRequestSent = "message.success.friend_request_sent"
    case successFriendRequestAccepted = "message.success.friend_request_accepted"
    case successFriendRequestDeclined = "message.success.friend_request_declined"
    case successFriendRemoved = "message.success.friend_removed"
    case successUserBlocked = "message.success.user_blocked"
    case successUserUnblocked = "message.success.user_unblocked"
    case successChatroomPinned = "message.success.chatroom_pinned"
    case successChatroomUnpinned = "message.success.chatroom_unpinned"
    case successChatroomMuted = "message.success.chatroom_muted"
    case successChatroomUnmuted = "message.success.chatroom_unmuted"
    case successChatroomCreated = "message.success.chatroom_created"
    case successChatroomUpdated = "message.success.chatroom_updated"
    case successChatroomArchived = "message.success.chatroom_archived"
    case successConversationDeleted = "message.success.conversation_deleted"
    case successAddedGuildWatchlist = "message.success.added_guild_watchlist"
    case successRemovedGuildWatchlist = "message.success.removed_guild_watchlist"
    case successAddedWatchlist = "message.success.added_watchlist"
    case successRemovedWatchlist = "message.success.removed_watchlist"
    case successRequestSubmitted = "message.success.request_submitted"
    case successEventShared = "message.success.event_shared"
    case successInviteLinkReady = "message.success.invite_link_ready"
    case successReferralAccepted = "message.success.referral_accepted"
    case successPasswordUpdatedSignIn = "message.success.password_updated_sign_in"
    case infoReferralSaved = "message.info.referral_saved"
    case infoAlreadyReportedUser = "message.info.report.user_already_submitted"
    case infoAlreadyReportedMessage = "message.info.report.message_already_submitted"
    case infoAlreadyReportedMarker = "message.info.report.marker_already_submitted"
    case errorFriendRequestsDisabled = "message.error.friends.requests_disabled"
}

enum RLUserFacingErrorContext: Equatable {
    case `default`
    case signIn
    case signup
    case appleSignIn
    case passwordReset
    case settings
    case guild
    case messaging
    case chart
}

enum RLUserFacingCopy {
    static func text(_ key: RLUserMessageKey) -> String {
        NSLocalizedString(
            key.rawValue,
            tableName: nil,
            bundle: .main,
            value: fallback(for: key),
            comment: ""
        )
    }

    static func format(_ key: RLUserMessageKey, _ args: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: args)
    }

    private static func fallback(for key: RLUserMessageKey) -> String {
        switch key {
        case .actionOk: return "OK"
        case .errorTitle: return "Error"
        case .warningTitle: return "Warning"
        case .successTitle: return "Success"
        case .infoTitle: return "Info"
        case .errorGeneric: return "Something went wrong. Please try again."
        case .errorNetwork: return "Network issue detected. Check your connection and try again."
        case .errorUnauthorized: return "Your session has expired. Please sign in again."
        case .errorAuthInvalidCredentials: return "Email/username or password is incorrect. Check your details and try again."
        case .errorAppleSignInInvalid: return "Apple sign-in could not be verified. Please try again."
        case .errorPasswordResetInvalidCode: return "This reset code is invalid or has expired. Request a new code and try again."
        case .errorCurrentPasswordIncorrect: return "Your current password is incorrect. Check it and try again."
        case .errorInvalidRequest: return "We couldn't complete that request."
        case .errorPermissionDenied: return "You don't have permission to do that."
        case .errorNotFound: return "We couldn't find that item. It may have been removed."
        case .errorConflict: return "That action has already been completed or conflicts with the current state."
        case .errorRateLimited: return "Too many attempts. Wait a moment and try again."
        case .errorServiceUnavailable: return "Service is temporarily unavailable. Please try again shortly."
        case .errorDecode: return "We received an unexpected response. Please try again."
        case .errorGuildApprovalRequired: return "This guild is private. Submit a join request instead."
        case .errorGuildLimitReached: return "You've reached your guild limit. Leave one to create a new guild."
        case .errorGuildCooldown: return "You cannot rejoin this guild yet. Please try again later."
        case .errorSetupConflict: return "You already have a setup marker for this symbol and timeframe."
        case .errorSetupLimit: return "You have reached your setup marker limit. Remove one before adding another."
        case .infoPasswordResetRequestFailed: return "We couldn't send a reset code right now. Please try again."
        case .infoPasswordResetFailed: return "Password reset failed. Verify your code and try again."
        case .warningPushPreferencesLoadFailed: return "Notification settings could not be loaded. Pull to refresh and try again."
        case .warningPushPreferencesSaveFailed: return "Notification setting was not saved. Please try again."
        case .successCopiedToClipboard: return "Copied to clipboard"
        case .successMessageDeleted: return "Message deleted"
        case .successMessageUpdated: return "Message updated"
        case .successReportSubmitted: return "Report submitted"
        case .errorNoGuildSelected: return "No guild selected."
        case .errorSelectGuildFirst: return "Please select a guild first."
        case .errorNoChartDataSelection: return "Please select a symbol and guild."
        case .errorCannotSendNoPermission: return "You don't have permission to send messages here."
        case .errorCannotSendBlockedUser: return "You have blocked this user."
        case .successWelcomeUser: return "Welcome to Traders Guild, %@!"
        case .infoLoggedOut: return "You've been logged out"
        case .infoSignInAgain: return "You can sign in again or start signup over."
        case .successJoinedGuildNamed: return "Joined %@ successfully!"
        case .successCreatedGuildNamed: return "Created %@ successfully!"
        case .successJoinRequestSubmitted: return "Join request submitted"
        case .successJoinRequestApproved: return "Join request approved"
        case .successJoinRequestDeclined: return "Join request declined"
        case .successAnnouncementPosted: return "Announcement posted!"
        case .successEventCreated: return "Event created!"
        case .successGuildSettingsUpdated: return "Guild settings updated!"
        case .successInviteSent: return "Invite sent!"
        case .successInviteCancelled: return "Invite cancelled"
        case .successJoinedGuild: return "Joined guild!"
        case .successMemberBanned: return "Member banned"
        case .successMemberUnbanned: return "Member unbanned"
        case .successMemberKicked: return "Member kicked"
        case .successMemberMuted: return "Member muted"
        case .successMemberUnmuted: return "Member unmuted"
        case .successMemberSuspended: return "Member suspended"
        case .successMemberUnsuspended: return "Member unsuspended"
        case .successRoleUpdated: return "Role updated to %@"
        case .successReportAction: return "Report %@"
        case .successProfileUpdated: return "Profile updated"
        case .successAvatarUpdated: return "Avatar updated"
        case .successAvatarRemoved: return "Avatar removed"
        case .successVerificationEmailSent: return "Verification email sent"
        case .successPasswordUpdated: return "Password updated"
        case .successDataExportRequested: return "Data export requested"
        case .successSupportTicketSubmitted: return "Support ticket submitted"
        case .successFriendRequestSent: return "Friend request sent"
        case .successFriendRequestAccepted: return "Friend request accepted"
        case .successFriendRequestDeclined: return "Friend request declined"
        case .successFriendRemoved: return "Friend removed"
        case .successUserBlocked: return "User blocked"
        case .successUserUnblocked: return "User unblocked"
        case .successChatroomPinned: return "Chatroom pinned"
        case .successChatroomUnpinned: return "Chatroom unpinned"
        case .successChatroomMuted: return "Chatroom muted"
        case .successChatroomUnmuted: return "Chatroom unmuted"
        case .successChatroomCreated: return "Chatroom created"
        case .successChatroomUpdated: return "Chatroom updated"
        case .successChatroomArchived: return "Chatroom archived"
        case .successConversationDeleted: return "Conversation deleted"
        case .successAddedGuildWatchlist: return "Added to guild watchlist"
        case .successRemovedGuildWatchlist: return "Removed from guild watchlist"
        case .successAddedWatchlist: return "Added to watchlist"
        case .successRemovedWatchlist: return "Removed from watchlist"
        case .successRequestSubmitted: return "Request submitted"
        case .successEventShared: return "Event shared"
        case .successInviteLinkReady: return "Invite link ready"
        case .successReferralAccepted: return "Referral accepted"
        case .successPasswordUpdatedSignIn: return "Password updated. Please sign in with your new password."
        case .infoReferralSaved: return "Referral saved. Sign up or log in to accept it."
        case .infoAlreadyReportedUser: return "You already reported this user. Moderators will review it."
        case .infoAlreadyReportedMessage: return "You already reported this message. Moderators will review it."
        case .infoAlreadyReportedMarker: return "You already reported this marker. Moderators will review it."
        case .errorFriendRequestsDisabled: return "Friend requests are disabled in your settings."
        }
    }
}

enum RLUserFacingErrorMapper {
    static func message(
        from error: Error,
        context: RLUserFacingErrorContext = .default
    ) -> String {
        if let apiError = error as? APIError {
            return message(from: apiError, context: context)
        }
        return sanitizedOrGeneric(error.localizedDescription)
    }

    private static func message(
        from apiError: APIError,
        context: RLUserFacingErrorContext
    ) -> String {
        switch apiError {
        case .unauthorized:
            if context == .signIn {
                return RLUserFacingCopy.text(.errorAuthInvalidCredentials)
            }
            if context == .appleSignIn {
                return RLUserFacingCopy.text(.errorAppleSignInInvalid)
            }
            return RLUserFacingCopy.text(.errorUnauthorized)
        case .invalidURL, .invalidResponse:
            return RLUserFacingCopy.text(.errorInvalidRequest)
        case .decodingError:
            return RLUserFacingCopy.text(.errorDecode)
        case .networkError:
            return RLUserFacingCopy.text(.errorNetwork)
        case .serverError(let statusCode, let detail):
            return userSafeServerMessage(statusCode: statusCode, detail: detail, context: context)
        case .badRequest(let detail):
            return userSafeBadRequestMessage(from: detail, context: context)
        }
    }

    private static func userSafeServerMessage(
        statusCode: Int,
        detail: String,
        context: RLUserFacingErrorContext
    ) -> String {
        switch statusCode {
        case 400, 422:
            return userSafeBadRequestMessage(from: detail, context: context)
        case 403:
            return RLUserFacingCopy.text(.errorPermissionDenied)
        case 404:
            return RLUserFacingCopy.text(.errorNotFound)
        case 409:
            if detail.lowercased().contains("already reported") {
                return alreadyReportedMessage(for: context)
            }
            return RLUserFacingCopy.text(.errorConflict)
        case 429:
            return RLUserFacingCopy.text(.errorRateLimited)
        default:
            return RLUserFacingCopy.text(.errorServiceUnavailable)
        }
    }

    private static func userSafeBadRequestMessage(
        from detail: String,
        context: RLUserFacingErrorContext
    ) -> String {
        let lower = detail.lowercased()
        if lower.contains("invalid credentials") {
            return RLUserFacingCopy.text(.errorAuthInvalidCredentials)
        }
        if lower.contains("invalid apple") || lower.contains("apple identity") {
            return RLUserFacingCopy.text(.errorAppleSignInInvalid)
        }
        if lower.contains("invalid password") {
            if context == .settings {
                return RLUserFacingCopy.text(.errorCurrentPasswordIncorrect)
            }
            return RLUserFacingCopy.text(.errorAuthInvalidCredentials)
        }
        if lower.contains("invalid or expired token")
            || lower.contains("invalid or expired verification code")
            || lower.contains("invalid or expired reset")
        {
            if context == .passwordReset {
                return RLUserFacingCopy.text(.errorPasswordResetInvalidCode)
            }
            return RLUserFacingCopy.text(.errorInvalidRequest)
        }
        if lower.contains("permission")
            || lower.contains("forbidden")
            || lower.contains("not allowed")
        {
            return RLUserFacingCopy.text(.errorPermissionDenied)
        }
        if lower.contains("too many")
            || lower.contains("rate limit")
            || lower.contains("rate_limit")
        {
            return RLUserFacingCopy.text(.errorRateLimited)
        }
        if lower.contains("already reported") {
            return alreadyReportedMessage(for: context)
        }
        if lower.contains("approval_required") {
            return RLUserFacingCopy.text(.errorGuildApprovalRequired)
        }
        if lower.contains("guild_create_limit_reached") {
            return RLUserFacingCopy.text(.errorGuildLimitReached)
        }
        if lower.contains("kicked_cooldown_active_until") {
            return RLUserFacingCopy.text(.errorGuildCooldown)
        }
        if lower.contains("tracked_setup_conflict_symbol_timeframe") {
            return RLUserFacingCopy.text(.errorSetupConflict)
        }
        if lower.contains("tracked_setup_limit_reached") {
            return RLUserFacingCopy.text(.errorSetupLimit)
        }
        return sanitizedOrGeneric(detail)
    }

    private static func alreadyReportedMessage(for context: RLUserFacingErrorContext) -> String {
        switch context {
        case .chart:
            return RLUserFacingCopy.text(.infoAlreadyReportedMarker)
        case .messaging:
            return RLUserFacingCopy.text(.infoAlreadyReportedMessage)
        default:
            return RLUserFacingCopy.text(.errorConflict)
        }
    }

    private static func sanitizedOrGeneric(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RLUserFacingCopy.text(.errorGeneric) }

        let lowered = trimmed.lowercased()
        let containsSensitiveToken = lowered.contains("http://")
            || lowered.contains("https://")
            || lowered.contains("[mode=")
            || lowered.contains("stack trace")
            || lowered.contains("traceback")
            || lowered.contains("sql")
            || lowered.contains("jwt")
            || lowered.contains("token")
            || lowered.contains("exception")
            || lowered.contains("server error")
            || lowered.contains("decoding")
            || lowered.contains("keychain")
            || lowered.contains("nsurl")

        if containsSensitiveToken {
            return RLUserFacingCopy.text(.errorGeneric)
        }

        if trimmed.count > 180 {
            return RLUserFacingCopy.text(.errorGeneric)
        }

        return trimmed
    }
}
