//
//  WalkthroughPreviewHarness.swift
//  traders_guild
//
//  DEBUG-only: presents the walkthrough exactly as MainView does, over a plain
//  background, with no backend or account. Launch with `-WalkthroughPreview`.
//

#if DEBUG
import SwiftUI

struct WalkthroughPreviewHarness: View {
    @State private var isPresented = true
    @State private var lastOutcome: WalkthroughOutcome?

    var body: some View {
        VStack(spacing: 16) {
            Text(lastOutcome.map { "Finished: \(String(describing: $0))" } ?? "Walkthrough preview")
                .foregroundColor(AppColors.greyText)
            Button("Show walkthrough") { isPresented = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.gradientBackgroundDark)
        .sheet(isPresented: $isPresented) {
            // Mirrors MainView's presentation so the card gets the same size.
            WalkthroughSheetView { outcome in
                lastOutcome = outcome
                isPresented = false
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
    }
}
#endif
