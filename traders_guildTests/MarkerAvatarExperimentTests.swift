import Foundation
import Testing
@testable import traders_guild

/// The v1.5 markers' switch: the server decides in every build and silence is
/// off; isolated DEV builds keep their development controls on top.
///
/// Run under both the LinkedDev scheme (isolated) and a plain Debug scheme
/// (not isolated) to cover both branches of the gate.
@Suite(.serialized)
struct MarkerAvatarExperimentTests {
    private let flag = MarkerAvatarExperiment.launchArgument

    @Test
    func offWithNothingSet() {
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: nil) == false)
    }

    @Test
    func theSavedSwitchTurnsItOn() {
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: true) == true)
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: false) == false)
    }

    @Test
    func aLaunchOverrideBeatsTheSavedSwitch() {
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag, "YES"], persisted: false) == true)
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag, "NO"], persisted: true) == false)
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag, "1"], persisted: nil) == true)
    }

    /// A typo or a dangling flag is not an instruction.
    @Test
    func anUnreadableOverrideFallsBackToTheSavedSwitch() {
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag, "maybe"], persisted: nil) == false)
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag], persisted: true) == true)
        #expect(MarkerAvatarExperiment.launchOverride(in: ["app", "-SomethingElse", "YES"]) == nil)
    }

    @Test
    func theSavedSwitchIsReadFromItsOwnSuite() throws {
        let suiteName = "MarkerAvatarExperimentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(MarkerAvatarExperiment.persistedValue(in: defaults) == nil)
        defaults.set(true, forKey: MarkerAvatarExperiment.defaultsKey)
        #expect(MarkerAvatarExperiment.persistedValue(in: defaults) == true)
    }

    /// The development controls are read only in isolated builds; the server
    /// decides everywhere.
    ///
    /// The test target does not share the app's compilation conditions, so the
    /// host app's build is identified independently of the gate under test: the
    /// isolated configurations, and only they, install as the LinkedDev bundle.
    @Test
    func onlyIsolatedDevBuildsHonourTheSavedSwitch() {
        let hostIsIsolatedDev = Bundle.main.bundleIdentifier == "co.tradersguild.app.linkeddev"
        #expect(MarkerAvatarExperiment.isAvailable == hostIsIsolatedDev)

        let defaults = UserDefaults.standard
        let keys = [MarkerAvatarExperiment.defaultsKey, MarkerAvatarExperiment.serverFlagKey]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        defaults.removeObject(forKey: MarkerAvatarExperiment.serverFlagKey)
        defaults.set(true, forKey: MarkerAvatarExperiment.defaultsKey)
        if hostIsIsolatedDev {
            #expect(MarkerAvatarExperiment.evaluate(serverFlag: false), "the saved switch beats the server in DEV")
            defaults.set(false, forKey: MarkerAvatarExperiment.defaultsKey)
            #expect(MarkerAvatarExperiment.evaluate(serverFlag: true) == false)
        } else {
            // Release, Prod QA, GCP Public Prod and plain Debug: the saved switch
            // and launch arguments are not read; only the server decides.
            #expect(MarkerAvatarExperiment.evaluate(serverFlag: nil) == false)
            #expect(MarkerAvatarExperiment.evaluate(serverFlag: true))
            #expect(MarkerAvatarExperiment.hasLaunchOverride == false)
        }
    }

    // MARK: Release enablement (server flag, fail closed)

    @Test
    func theServerDecidesAndSilenceIsOff() {
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: nil, serverFlag: nil) == false)
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: nil, serverFlag: true))
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: nil, serverFlag: false) == false)
        // Development controls, where read, still win.
        #expect(MarkerAvatarExperiment.resolve(arguments: ["app", flag, "NO"], persisted: nil, serverFlag: true) == false)
        #expect(MarkerAvatarExperiment.resolve(arguments: [], persisted: true, serverFlag: false))
    }

    @Test
    func theServersLastAnswerIsKeptInItsOwnKey() throws {
        let suiteName = "MarkerAvatarExperimentTests.server.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(MarkerAvatarExperiment.persistedServerFlag(in: defaults) == nil)
        defaults.set(true, forKey: MarkerAvatarExperiment.serverFlagKey)
        #expect(MarkerAvatarExperiment.persistedServerFlag(in: defaults) == true)
        #expect(MarkerAvatarExperiment.persistedValue(in: defaults) == nil, "not the development switch")
    }

    /// The flag arrives before anything asks: it decides this launch.
    @Test
    func anAnswerBeforeTheFirstReadDecidesThisLaunch() {
        let latch = MarkerLaunchLatch()
        latch.offer { true }
        #expect(latch.value { false })
        latch.offer { false }
        #expect(latch.value { false }, "later answers wait for the next launch")
    }

    /// Something asks first: what was known then decides; a later answer waits.
    @Test
    func aFirstReadBeforeTheAnswerKeepsWhatWasKnown() {
        let latch = MarkerLaunchLatch()
        #expect(latch.isDecided == false)
        #expect(latch.value { false } == false, "fail closed: nothing known yet")
        latch.offer { true }
        #expect(latch.value { true } == false)
        #expect(latch.isDecided)
    }

    @Test
    func runtimeFlagsDecodeTheAvatarMarkersFlag() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let on = try decoder.decode(RLRuntimeFlagsDTO.self, from: Data(#"{"avatar_markers_enabled": true, "linked_markers_enabled": true}"#.utf8))
        #expect(on.avatarMarkersEnabled && on.linkedMarkersEnabled)
        // A server that predates the flag: off.
        let older = try decoder.decode(RLRuntimeFlagsDTO.self, from: Data(#"{"linked_markers_enabled": true}"#.utf8))
        #expect(older.avatarMarkersEnabled == false)
        #expect(RLRuntimeFlagsDTO.disabled.avatarMarkersEnabled == false)
    }

    @Test
    func thePrototypeCoversThePostTypesAndSetup() {
        #expect(MarkerAvatarPresentation.avatarIntents(experimentEnabled: false) == [.personal])
        #expect(
            MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
                == [.analysis, .question, .poll, .alert, .setup, .personal]
        )
    }
}
