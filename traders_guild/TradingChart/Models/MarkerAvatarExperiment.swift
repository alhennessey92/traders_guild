//
//  MarkerAvatarExperiment.swift
//  traders_guild
//
//  The v1.5 avatar-led marker prototype's one switch.
//

import Foundation
import os

/// Whether the v1.5 avatar-led markers are on.
///
/// The server decides, in every configuration: the authenticated runtime flag
/// `avatar_markers_enabled` (`GET /users/me/runtime-flags`; an env master
/// switch with an admin kill switch under it). The app **fails closed**: with
/// no answer from the server, ever, it runs the old marker system.
///
/// Decided once per launch, so nothing switches under the user's hands:
/// - if the server's answer arrives before anything asks (the usual case: the
///   flags are fetched as soon as the app is signed in), it decides this launch;
/// - otherwise the answer last persisted from the server decides, and a new
///   answer takes effect on the next launch.
///
/// The isolated DEV configurations (`TG_ISOLATED_DEV`: DevDebug and the
/// optimised DevProfile) keep two development controls that win over the
/// server, launch first:
/// - Launch override, for reproducible device and simulator runs:
///   `-TGAvatarMarkersExperiment YES` (or `NO`). Not persisted.
/// - Persisted switch, set from the marker fixture gallery.
/// No other configuration reads either.
enum MarkerAvatarExperiment {
    static let defaultsKey = "TGAvatarMarkersExperiment"
    /// The server's last answer, kept for launches before the next fetch.
    static let serverFlagKey = "TGAvatarMarkersServerFlag"
    static let launchArgument = "-TGAvatarMarkersExperiment"

    /// Whether this build offers the development controls.
    static var isAvailable: Bool {
        #if TG_ISOLATED_DEV
        return true
        #else
        return false
        #endif
    }

    private static let launchLatch = MarkerLaunchLatch()

    /// Decided once per launch. Marker badges read this in view bodies, so
    /// after the first read it is one uncontended lock and a stored value.
    static var isEnabled: Bool {
        launchLatch.value { evaluate() }
    }

    /// The server's answer, from the runtime flags. Persisted for the next
    /// launch; it also decides this launch if nothing has asked yet.
    static func recordServerFlag(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: serverFlagKey)
        launchLatch.offer { evaluate(serverFlag: enabled) }
    }

    /// The switch as it stands right now: the development controls in an
    /// isolated build, then the server's answer (given, or last persisted),
    /// then off.
    static func evaluate(serverFlag: Bool? = nil) -> Bool {
        let server = serverFlag ?? persistedServerFlag(in: .standard)
        #if TG_ISOLATED_DEV
        return resolve(
            arguments: ProcessInfo.processInfo.arguments,
            persisted: persistedValue(in: .standard),
            serverFlag: server
        )
        #else
        return resolve(arguments: [], persisted: nil, serverFlag: server)
        #endif
    }

    /// Whether a launch argument, rather than the saved switch, decides.
    static var hasLaunchOverride: Bool {
        #if TG_ISOLATED_DEV
        return launchOverride(in: ProcessInfo.processInfo.arguments) != nil
        #else
        return false
        #endif
    }

    #if TG_ISOLATED_DEV
    static func setPersisted(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: defaultsKey)
    }
    #endif

    // MARK: - Resolution

    /// The rule, separate from where its inputs come from so it can be tested
    /// in any configuration. A launch override wins; then the saved development
    /// switch; then the server; otherwise off (fail closed).
    static func resolve(arguments: [String], persisted: Bool?, serverFlag: Bool? = nil) -> Bool {
        launchOverride(in: arguments) ?? persisted ?? serverFlag ?? false
    }

    /// The server's last answer, if it has ever given one. Like the saved
    /// switch, read from the app's own persistent domain only, so a launch
    /// argument can never stand in for the server.
    static func persistedServerFlag(in defaults: UserDefaults) -> Bool? {
        if defaults === UserDefaults.standard {
            guard let domainName = Bundle.main.bundleIdentifier else { return nil }
            return defaults.persistentDomain(forName: domainName)?[serverFlagKey] as? Bool
        }
        return defaults.object(forKey: serverFlagKey) as? Bool
    }

    /// `YES`/`NO` (or `true`/`false`, `1`/`0`) after the argument. A missing or
    /// unrecognised value is no override, so a typo cannot silently enable it.
    static func launchOverride(in arguments: [String]) -> Bool? {
        guard let index = arguments.lastIndex(of: launchArgument),
              arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1].lowercased() {
        case "yes", "true", "1": return true
        case "no", "false", "0": return false
        default: return nil
        }
    }

    /// Reads only the app's own persistent domain, never the argument domain
    /// `UserDefaults` layers on top, so the persisted switch and the launch
    /// override stay distinguishable.
    static func persistedValue(in defaults: UserDefaults) -> Bool? {
        if defaults === UserDefaults.standard {
            guard let domainName = Bundle.main.bundleIdentifier else { return nil }
            return defaults.persistentDomain(forName: domainName)?[defaultsKey] as? Bool
        }
        return defaults.object(forKey: defaultsKey) as? Bool
    }
}

/// A value decided once per launch: by whichever comes first, the first read
/// (from what is known then) or an offer of a fresher answer. Later offers do
/// not change it.
final class MarkerLaunchLatch: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<Bool?>(initialState: nil)

    func value(_ evaluate: () -> Bool) -> Bool {
        state.withLock { value in
            if let value { return value }
            let decided = evaluate()
            value = decided
            return decided
        }
    }

    func offer(_ evaluate: () -> Bool) {
        state.withLock { value in
            if value == nil { value = evaluate() }
        }
    }

    var isDecided: Bool { state.withLock { $0 != nil } }
}

