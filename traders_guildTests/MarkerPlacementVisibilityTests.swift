//
//  MarkerPlacementVisibilityTests.swift
//  traders_guildTests
//
//  A personal marker is about *you*, not about how visible it is.
//
//  It used to be private by construction: `MarkerPlacementState` overwrote the author's
//  choice with "private" on both submit paths, so a personal marker could never be shared
//  no matter what the UI offered. The author now chooses, and sharing keys off that choice
//  exactly as it does for every other intent (`MarkerShareKitTests` covers the sharing side).
//
//  These pin the rule that survives the round trip: the choice reaches the request.
//

import Testing
@testable import traders_guild

@MainActor
struct MarkerPlacementVisibilityTests {

    private func state(intent: RLMarkerIntent, visibility: String) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.intent = intent
        state.visibility = visibility
        return state
    }

    @Test func aPersonalMarkerKeepsTheVisibilityItsAuthorChose() {
        #expect(state(intent: .personal, visibility: "private").submittedVisibility == "private")
        #expect(state(intent: .personal, visibility: "guild").submittedVisibility == "guild")
    }

    @Test func everyOtherIntentIsAlwaysAGuildPost() {
        // Nothing else offers the choice, so a stray value must not reach the backend.
        for intent in RLMarkerIntent.allCases where intent != .personal {
            #expect(state(intent: intent, visibility: "private").submittedVisibility == "guild")
        }
    }

    @Test func onlyPersonalMarkersOfferTheChoice() {
        #expect(state(intent: .personal, visibility: "private").allowsVisibilityChoice)
        for intent in RLMarkerIntent.allCases where intent != .personal {
            #expect(!state(intent: intent, visibility: "guild").allowsVisibilityChoice)
        }
    }

    @Test func switchingToPersonalDefaultsToPrivateWithoutLockingIt() {
        let placement = MarkerPlacementState()
        placement.setIntent(.personal)
        #expect(placement.visibility == "private")

        // The author can still open it up — this is what used to be impossible.
        placement.visibility = "guild"
        #expect(placement.submittedVisibility == "guild")
    }

    @Test func switchingAwayFromPersonalReturnsToAGuildPost() {
        let placement = MarkerPlacementState()
        placement.setIntent(.personal)
        placement.setIntent(.analysis)
        #expect(placement.submittedVisibility == "guild")
    }
}
