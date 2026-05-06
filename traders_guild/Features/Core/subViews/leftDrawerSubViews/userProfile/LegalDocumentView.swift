//
//  LegalDocumentView.swift
//  traders_guild
//
//  Reusable in-app viewer for bundled markdown legal documents
//  (Terms of Service, Privacy Policy, Community Guidelines, Legal Information).
//
//  Loads from Resources/support/<resourceName>.md and renders via
//  AttributedString(markdown:). Falls back to plain text on parse failure.
//

import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let resourceName: String
    let onBack: () -> Void

    @State private var rawText: String = ""
    @State private var attributed: AttributedString?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsSubViewHeader(title: title, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let attributed = attributed {
                            Text(attributed)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else if !rawText.isEmpty {
                            Text(rawText)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else if let loadError = loadError {
                            Text(loadError)
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
            loadDocument()
        }
    }

    private func loadDocument() {
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "md",
            subdirectory: "support"
        ) ?? Bundle.main.url(forResource: resourceName, withExtension: "md") else {
            loadError = "Document unavailable. Please check back soon."
            return
        }

        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            rawText = raw

            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .full
            if let parsed = try? AttributedString(markdown: raw, options: options) {
                attributed = parsed
            }
        } catch {
            loadError = "Could not load document: \(error.localizedDescription)"
        }
    }
}
