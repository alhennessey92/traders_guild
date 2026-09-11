//
//  AppLogoMark.swift
//  traders_guild
//
//  The square App Store icon, drawn in-app.
//

import SwiftUI

/// The app's square icon, composed from the same two layers Icon Composer
/// builds the App Store icon from, so what the user sees in the app is the
/// icon they tapped to open it.
///
/// One component, used everywhere the brand mark appears in-app — the About
/// screen and the launch transition — so the two cannot drift. The corner
/// radius tracks the iOS icon shape proportionally rather than being a fixed
/// number, which is what lets one view serve a 100pt About tile and a 60pt
/// transition badge without looking like two different logos.
struct AppLogoMark: View {
    var size: CGFloat = 100
    var showsStroke: Bool = true
    var showsShadow: Bool = true

    /// iOS renders the home-screen icon with a continuous corner of roughly
    /// 22.4% of its side.
    private var cornerRadius: CGFloat { size * 0.224 }

    var body: some View {
        ZStack {
            if let backgroundImage = Self.bundleImage(named: "appiconbg 2") {
                backgroundImage
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
            }

            if let logoImage = Self.bundleImage(named: "TG 3") {
                logoImage
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
            } else {
                Text("TG")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(AppColors.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showsStroke {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
            }
        }
        .shadow(
            color: showsShadow ? AppColors.surfaceBlack20 : .clear,
            radius: showsShadow ? size * 0.12 : 0,
            x: 0,
            y: showsShadow ? size * 0.06 : 0
        )
        // Decorative: the surrounding view supplies the spoken name.
        .accessibilityHidden(true)
    }

    /// The icon layers are bundled resources, not asset-catalog images, so
    /// they are read from the bundle by name. Falls back to a top-level lookup
    /// for a build that flattens the resource folder.
    static func bundleImage(named name: String) -> Image? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "AppIconPreview/Assets"
        ) ?? Bundle.main.url(forResource: name, withExtension: "png"),
        let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: image)
    }
}
