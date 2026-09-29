import Foundation
import Testing
@testable import traders_guild

/// The avatar prototype's switch must be reachable in isolated DEV builds and
/// impossible to turn on anywhere else.
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

    /// The build decides whether the saved preference is even looked at.
    ///
    /// The test target does not share the app's compilation conditions, so the
    /// host app's build is identified independently of the gate under test: the
    /// isolated configurations, and only they, install as the LinkedDev bundle.
    @Test
    func onlyIsolatedDevBuildsHonourTheSavedSwitch() {
        let hostIsIsolatedDev = Bundle.main.bundleIdentifier == "co.tradersguild.app.linkeddev"
        #expect(MarkerAvatarExperiment.isAvailable == hostIsIsolatedDev)

        let defaults = UserDefaults.standard
        let key = MarkerAvatarExperiment.defaultsKey
        let previous = defaults.object(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
        }

        defaults.set(true, forKey: key)
        if hostIsIsolatedDev {
            #expect(MarkerAvatarExperiment.isEnabled)
            defaults.set(false, forKey: key)
            #expect(MarkerAvatarExperiment.isEnabled == false)
        } else {
            // Release, Prod QA, GCP Public Prod and plain Debug: compiled to `false`.
            #expect(MarkerAvatarExperiment.isEnabled == false)
            #expect(MarkerAvatarExperiment.hasLaunchOverride == false)
        }
    }

    @Test
    func thePrototypeCoversExactlyItsThreeIntents() {
        #expect(MarkerAvatarPresentation.avatarIntents(experimentEnabled: false) == [.personal])
        #expect(
            MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
                == [.analysis, .question, .setup, .personal]
        )
    }
}
