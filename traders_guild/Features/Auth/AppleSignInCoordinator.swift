//
//  AppleSignInCoordinator.swift
//  traders_guild
//
//  Apple Sign-In coordinator using AuthenticationServices.
//  Handles the ASAuthorization flow and delegates back to the auth system.
//

import AuthenticationServices
import SwiftUI

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    struct AppleSignInResult {
        let identityToken: String
        let authorizationCode: String
        let fullName: PersonNameComponents?
        let email: String?
    }

    enum AppleSignInError: Error, LocalizedError {
        case cancelled
        case invalidCredential
        case missingToken

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Apple sign-in was cancelled."
            case .invalidCredential: return "Invalid Apple credential received."
            case .missingToken: return "Apple identity token missing."
            }
        }
    }

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
            continuation = nil
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authCodeData, encoding: .utf8) else {
            continuation?.resume(throwing: AppleSignInError.missingToken)
            continuation = nil
            return
        }

        let result = AppleSignInResult(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: appleIDCredential.fullName,
            email: appleIDCredential.email
        )

        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
