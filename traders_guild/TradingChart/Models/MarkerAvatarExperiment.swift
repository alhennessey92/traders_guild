//
//  MarkerAvatarExperiment.swift
//  traders_guild
//
//  The v1.5 avatar-led marker prototype's one switch.
//

import Foundation

/// Whether the avatar-led marker prototype is on.
///
/// Available only in the isolated DEV configurations (`TG_ISOLATED_DEV`:
/// DevDebug and the optimised DevProfile), so it can be exercised in a build
/// that profiles like the shipping app. Every other configuration — Release,
/// GCP Public Prod, Prod QA and the plain Debug schemes — compiles the switch
/// to a constant `false`: no launch argument or saved preference is read, so
/// neither can turn it on.
///
/// Off by default. Two development controls, launch first:
/// - Launch override, for reproducible device and simulator runs:
///   `-TGAvatarMarkersExperiment YES` (or `NO`). Not persisted.
/// - Persisted switch, for launches from the home screen, which carry no
///   arguments: set from the marker fixture gallery. Read at launch.
enum MarkerAvatarExperiment {
    static let defaultsKey = "TGAvatarMarkersExperiment"
    static let launchArgument = "-TGAvatarMarkersExperiment"

    /// Whether this build can host the experiment at all.
    static var isAvailable: Bool {
        #if TG_ISOLATED_DEV
        return true
        #else
        return false
        #endif
    }

    /// Decided once per launch. Marker badges read this in view bodies, so it
    /// must not touch `UserDefaults` every time; a changed saved switch takes
    /// effect on the next launch.
    static let isEnabled: Bool = evaluate()

    /// The switch as it stands right now.
    static func evaluate() -> Bool {
        #if TG_ISOLATED_DEV
        return resolve(
            arguments: ProcessInfo.processInfo.arguments,
            persisted: persistedValue(in: .standard)
        )
        #else
        return false
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
    /// in any configuration. A launch override wins; otherwise the saved switch;
    /// otherwise off.
    static func resolve(arguments: [String], persisted: Bool?) -> Bool {
        launchOverride(in: arguments) ?? persisted ?? false
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
