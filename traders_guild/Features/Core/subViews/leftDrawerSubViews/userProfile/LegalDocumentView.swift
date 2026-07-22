//
//  LegalDocumentView.swift
//  traders_guild
//
//  Reusable in-app viewer for bundled supporting documents such as the
//  Community Guidelines and Legal Information. Terms and Privacy use their
//  canonical web URLs so App Review sees the current published documents.
//
//  Loads from Resources/support/<resourceName>.md and renders block-level
//  markdown — headings, paragraphs, lists, dividers — as styled SwiftUI
//  views. Inline formatting (bold/italic) goes through AttributedString.
//

import SwiftUI

enum TradersGuildLegalURL {
    static let terms = URL(string: "https://tradersguild.co/terms")!
    static let privacy = URL(string: "https://tradersguild.co/privacy")!
}

struct LegalDocumentView: View {
    let title: String
    let resourceName: String
    let onBack: () -> Void

    @State private var blocks: [MarkdownBlock] = []
    @State private var loadError: String?

    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsSubViewHeader(title: title, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !blocks.isEmpty {
                            ForEach(blocks.indices, id: \.self) { index in
                                blockView(blocks[index])
                            }
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
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .textSelection(.enabled)
                }
            }
        }
        .task {
            loadDocument()
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .h1(let text):
            Text(inlineAttributed(text))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.whiteText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
                .padding(.bottom, 2)

        case .h2(let text):
            Text(inlineAttributed(text))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.whiteText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
                .padding(.bottom, 2)

        case .h3(let text):
            Text(inlineAttributed(text))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.whiteText.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 2)

        case .paragraph(let text):
            Text(inlineAttributed(text))
                .font(.system(size: 15))
                .foregroundColor(AppColors.whiteText.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.accentColor)
                            .frame(width: 10, alignment: .leading)
                        Text(inlineAttributed(items[index]))
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.whiteText.opacity(0.85))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case .numbered(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.accentColor)
                            .frame(width: 22, alignment: .leading)
                        Text(inlineAttributed(items[index]))
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.whiteText.opacity(0.85))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case .divider:
            Rectangle()
                .fill(AppColors.whiteText.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 8)
        }
    }

    private func inlineAttributed(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
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
            blocks = MarkdownBlockParser.parse(raw)
        } catch {
            loadError = "Could not load document: \(error.localizedDescription)"
        }
    }
}

// MARK: - Block model

enum MarkdownBlock {
    case h1(String)
    case h2(String)
    case h3(String)
    case paragraph(String)
    case bullet([String])
    case numbered([String])
    case divider
}

// MARK: - Block parser
//
// Lightweight, line-oriented markdown parser. Handles the subset used by
// our bundled legal documents:
//   # / ## / ### headings
//   --- horizontal rules
//   - / * bullet lists (consecutive lines grouped)
//   1. 2. … numbered lists (consecutive lines grouped)
//   blank-line-separated paragraphs (consecutive non-list, non-heading
//   lines joined into a single paragraph so wrapping behaves naturally)
// Inline syntax (**bold**, *italic*, [links]) is left untouched here and
// rendered downstream by AttributedString(markdown:).
//
enum MarkdownBlockParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var bulletItems: [String] = []
        var numberedItems: [String] = []

        func flushParagraph() {
            if !paragraphLines.isEmpty {
                let text = paragraphLines.joined(separator: " ")
                blocks.append(.paragraph(text))
                paragraphLines.removeAll(keepingCapacity: true)
            }
        }

        func flushBullets() {
            if !bulletItems.isEmpty {
                blocks.append(.bullet(bulletItems))
                bulletItems.removeAll(keepingCapacity: true)
            }
        }

        func flushNumbered() {
            if !numberedItems.isEmpty {
                blocks.append(.numbered(numberedItems))
                numberedItems.removeAll(keepingCapacity: true)
            }
        }

        func flushAll() {
            flushParagraph()
            flushBullets()
            flushNumbered()
        }

        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" })

        for rawLine in lines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushAll()
                blocks.append(.divider)
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushAll()
                blocks.append(.h3(String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushAll()
                blocks.append(.h2(String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if trimmed.hasPrefix("# ") {
                flushAll()
                blocks.append(.h1(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                flushNumbered()
                bulletItems.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }

            if let numberedContent = stripNumberedPrefix(trimmed) {
                flushParagraph()
                flushBullets()
                numberedItems.append(numberedContent)
                continue
            }

            // Plain text line — accumulate into the current paragraph,
            // closing any list that was open.
            flushBullets()
            flushNumbered()
            paragraphLines.append(trimmed)
        }

        flushAll()
        return blocks
    }

    /// Returns the body of a numbered-list line ("1. foo" → "foo"),
    /// or nil if the line isn't a numbered-list item.
    private static func stripNumberedPrefix(_ line: String) -> String? {
        var index = line.startIndex
        var sawDigit = false
        while index < line.endIndex, line[index].isNumber {
            sawDigit = true
            index = line.index(after: index)
        }
        guard sawDigit, index < line.endIndex, line[index] == "." else { return nil }
        let afterDot = line.index(after: index)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        let body = line[line.index(after: afterDot)...]
        return body.trimmingCharacters(in: .whitespaces)
    }
}
