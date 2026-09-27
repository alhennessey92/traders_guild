//
//  WalkthroughSheetView.swift
//  traders_guild
//
//  The first-run walkthrough: five swipeable pages, each a looping clip in a
//  phone frame with a headline and a line or two. Presented as a large sheet
//  from MainView once after account creation, and from Settings on demand.
//

import SwiftUI

struct WalkthroughSheetView: View {
    /// Called exactly once with how the walkthrough ended. The caller dismisses
    /// the sheet and persists completion; a swipe-down never reaches this and is
    /// treated as `.skipped` by the sheet's onDismiss.
    let onFinish: (WalkthroughOutcome) -> Void

    @StateObject private var presenter = WalkthroughPresenter()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var didFinish = false

    var body: some View {
        // A card, not a full-bleed sheet: the presentation background is cleared in MainView, so
        // this floats over the dimmed chart with the app's own corner radius on all four sides.
        VStack(spacing: 0) {
            header

            TabView(selection: $presenter.currentPage) {
                ForEach(presenter.pages) { page in
                    WalkthroughPageView(
                        page: page,
                        presenter: presenter,
                        reduceMotion: reduceMotion
                    )
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(
            ZStack {
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .onAppear {
            if !reduceMotion {
                presenter.showClip(for: presenter.currentPage)
            }
        }
        .onChange(of: presenter.currentPage) { _, page in
            if !reduceMotion {
                presenter.showClip(for: page)
            }
        }
        .onChange(of: reduceMotion) { _, reduce in
            if reduce {
                presenter.tearDown()
            } else {
                presenter.showClip(for: presenter.currentPage)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                presenter.resumeVisible()
            } else {
                presenter.pauseAll()
            }
        }
        .onDisappear {
            presenter.tearDown()
        }
    }

    // MARK: - Header

    /// "Skip" on every page but the last, where the same corner offers "Explore first" — the
    /// way out that does not place a marker. Keeping it up here rather than under the button
    /// leaves the footer one row tall on every page, so the clip gets the height instead.
    private var header: some View {
        HStack {
            Spacer()
            Button(presenter.currentPage.secondaryButtonTitle ?? "Skip") {
                finish(presenter.isOnLastPage ? .completed : .skipped)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.greyText)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .accessibilityHint("Closes the walkthrough")
            .animation(nil, value: presenter.currentPage)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 6) {
                pageDots
                    .padding(.top, 8)

                StandardActionButtonFullWidth(
                    title: presenter.currentPage.primaryButtonTitle,
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark
                ) {
                    if presenter.isOnLastPage {
                        finish(.placeFirstMarker)
                    } else {
                        presenter.advance()
                    }
                }
                // Dots and one button on every page, so the footer never changes height and the
                // clip above never jumps. The last page's way out is the header's corner button
                // and its footnote sits under that page's copy.
            }
            .padding(.horizontal, 8)
            // The button carries its own 16pt inset, which is the whole gap to the card's edge.
            .background(AppColors.sheetBackground)
        }
        .animation(.easeInOut(duration: 0.2), value: presenter.currentPage)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(presenter.pages) { page in
                Capsule()
                    .fill(page == presenter.currentPage
                          ? AppColors.whiteText
                          : AppColors.whiteText.opacity(0.25))
                    .frame(width: page == presenter.currentPage ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(presenter.pageIndex + 1) of \(presenter.pages.count)")
    }

    private func finish(_ outcome: WalkthroughOutcome) {
        guard !didFinish else { return }
        didFinish = true
        presenter.tearDown()
        onFinish(outcome)
    }
}

// MARK: - Page

private struct WalkthroughPageView: View {
    let page: WalkthroughPage
    @ObservedObject var presenter: WalkthroughPresenter
    let reduceMotion: Bool

    @State private var isClipReady = false
    /// Natural height of this page's headline + body, so the clip can take the rest.
    @State private var copyHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            // Copy takes its natural height; the edited clip fits in the remaining space.
            let mediaWidth = geometry.size.width - 24
            let available = geometry.size.height - 18
            // The copy takes what it needs, up to a limit; the clip takes the rest exactly, so the
            // two always sum to the page and nothing spills over the dots below.
            let copyArea = min(available * 0.42, max(104, copyHeight))
            let mediaHeight = available - copyArea

            VStack(spacing: 14) {
                media(width: mediaWidth, height: mediaHeight)

                // Scrolls only when Dynamic Type pushes the copy past the space
                // left under the clip, so nothing is ever clipped or truncated.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        Text(page.title)
                            .font(.title3.bold())
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.center)

                        Text(page.body)
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let footnote = page.footnote {
                            Text(footnote)
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    // Clear of the footer's divider (measured with the copy, so the clip allows for it).
                    .padding(.bottom, 8)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: WalkthroughCopyHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: copyArea)
            }
            .padding(.top, 4)
            .onPreferenceChange(WalkthroughCopyHeightKey.self) { height in
                copyHeight = height
            }
        }
    }

    /// The edited camera frame fits inside the available window without losing its controls.
    private func media(width: CGFloat, height: CGFloat) -> some View {
        // Preserve the complete edited camera frame, with the poster and player aligned.
        let placement = page.clipPlacement(in: CGSize(width: width, height: height))
        return ZStack {
            WalkthroughPosterImage(url: page.posterURL())
                .accessibilityLabel(page.title)

            #if canImport(UIKit)
            if !reduceMotion, let player = presenter.player(for: page) {
                WalkthroughVideoView(player: player) { ready in
                    isClipReady = ready
                }
                .opacity(isClipReady ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: isClipReady)
                .accessibilityHidden(true)
            }
            #endif
        }
        .frame(width: placement.size.width, height: placement.size.height)
        .offset(y: -placement.offsetY)
        .frame(width: width, height: height, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct WalkthroughCopyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
