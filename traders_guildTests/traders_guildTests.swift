//
//  traders_guildTests.swift
//  traders_guildTests
//
//  Created by Al Hennessey on 16/07/2025.
//

import Testing
@testable import traders_guild

struct traders_guildTests {

    @Test func emailIdentifierValidation() async throws {
        #expect(RLAuthValidator.isValidIdentifier("user@example.com"))
        #expect(!RLAuthValidator.isValidIdentifier("invalid@email"))
    }

    @Test func usernameValidation() async throws {
        #expect(RLAuthValidator.isValidUsername("alpha_trader-01"))
        #expect(!RLAuthValidator.isValidUsername("ab"))
        #expect(!RLAuthValidator.isValidUsername("bad username with spaces"))
    }

    @Test func passwordValidation() async throws {
        #expect(RLAuthValidator.isValidPassword("StrongPass1"))
        #expect(!RLAuthValidator.isValidPassword("weak"))
        #expect(!RLAuthValidator.isValidPassword("alllowercase123"))
        #expect(!RLAuthValidator.isValidPassword("ALLUPPERCASE123"))
        #expect(!RLAuthValidator.isValidPassword("NoNumberPassword"))
    }

    @Test func confirmPasswordValidation() async throws {
        #expect(RLAuthValidator.doPasswordsMatch("StrongPass1", "StrongPass1"))
        #expect(!RLAuthValidator.doPasswordsMatch("StrongPass1", "StrongPass2"))
    }

}
