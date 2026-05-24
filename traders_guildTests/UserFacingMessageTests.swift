import Testing
@testable import traders_guild

struct UserFacingMessageTests {

    @Test func signInUnauthorizedUsesHelpfulSafeCredentialsCopy() async throws {
        let message = RLUserFacingErrorMapper.message(from: APIError.unauthorized, context: .signIn)

        #expect(message == "Email/username or password is incorrect. Check your details and try again.")
    }

    @Test func defaultUnauthorizedUsesExpiredSessionCopy() async throws {
        let message = RLUserFacingErrorMapper.message(from: APIError.unauthorized)

        #expect(message == "Your session has expired. Please sign in again.")
    }

    @Test func invalidCurrentPasswordUsesSettingsCopy() async throws {
        let message = RLUserFacingErrorMapper.message(
            from: APIError.badRequest("Invalid password"),
            context: .settings
        )

        #expect(message == "Your current password is incorrect. Check it and try again.")
    }

    @Test func resetTokenErrorsUsePasswordResetCopy() async throws {
        let message = RLUserFacingErrorMapper.message(
            from: APIError.badRequest("Invalid or expired token"),
            context: .passwordReset
        )

        #expect(message == "This reset code is invalid or has expired. Request a new code and try again.")
    }

    @Test func statusCodesMapToUsefulSafeMessages() async throws {
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.serverError(403, "Forbidden"))
            == "You don't have permission to do that."
        )
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.serverError(404, "Missing"))
            == "We couldn't find that item. It may have been removed."
        )
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.serverError(409, "Already exists"))
            == "That action has already been completed or conflicts with the current state."
        )
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.serverError(429, "Too many requests"))
            == "Too many attempts. Wait a moment and try again."
        )
    }

    @Test func commonSystemErrorsRemainHelpfulAndSafe() async throws {
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.networkError("request_failed"))
            == "Network issue detected. Check your connection and try again."
        )
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.decodingError("response_decode_failed"))
            == "We received an unexpected response. Please try again."
        )
        #expect(
            RLUserFacingErrorMapper.message(from: APIError.serverError(500, "database unavailable"))
            == "Service is temporarily unavailable. Please try again shortly."
        )
    }

    @Test func sensitiveRawDetailsCollapseToGenericCopy() async throws {
        let message = RLUserFacingErrorMapper.message(
            from: APIError.badRequest("Traceback with token https://example.com/internal")
        )

        #expect(message == "Something went wrong. Please try again.")
    }
}
