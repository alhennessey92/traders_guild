import SwiftUI
import Foundation

struct NewsLinkPreview: Equatable {
    let resolvedURL: URL
    let domain: String
    let title: String
    let snippet: String?
    let imageURL: URL?
}

actor NewsLinkPreviewService {
    static let shared = NewsLinkPreviewService()

    private var cache: [String: NewsLinkPreview] = [:]
    private var failedKeys = Set<String>()

    func preview(for url: URL) async -> NewsLinkPreview? {
        let key = url.absoluteString
        if let cached = cache[key] {
            return cached
        }
        if failedKeys.contains(key) {
            return nil
        }

        guard let preview = try? await fetchPreview(for: url) else {
            failedKeys.insert(key)
            return nil
        }

        cache[key] = preview
        return preview
    }

    private func fetchPreview(for url: URL) async throws -> NewsLinkPreview {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let finalURL = response.url else {
            throw URLError(.badServerResponse)
        }

        let html = Self.decodeHTMLDocument(from: data)
        guard !html.isEmpty else {
            throw URLError(.cannotDecodeRawData)
        }

        let title = Self.extractTitle(from: html) ?? Self.fallbackTitle(from: finalURL)
        let snippet = Self.extractDescription(from: html)
        let imageURL = Self.extractImageURL(from: html, baseURL: finalURL)

        return NewsLinkPreview(
            resolvedURL: finalURL,
            domain: Self.domainLabel(for: finalURL),
            title: title,
            snippet: snippet,
            imageURL: imageURL
        )
    }

    private static func decodeHTMLDocument(from data: Data) -> String {
        if let html = String(data: data, encoding: .utf8) {
            return html
        }
        if let html = String(data: data, encoding: .utf16) {
            return html
        }
        if let html = String(data: data, encoding: .isoLatin1) {
            return html
        }
        return ""
    }

    private static func fallbackTitle(from url: URL) -> String {
        let lastPath = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
        let trimmed = normalize(lastPath)
        guard let trimmed, !trimmed.isEmpty else {
            return domainLabel(for: url)
        }
        return trimmed.capitalized
    }

    private static func extractTitle(from html: String) -> String? {
        extractMetaContent(names: ["og:title", "twitter:title"], in: html)
        ?? extractTagContent(tag: "title", in: html)
    }

    private static func extractDescription(from html: String) -> String? {
        extractMetaContent(
            names: ["og:description", "twitter:description", "description"],
            in: html
        )
    }

    private static func extractImageURL(from html: String, baseURL: URL) -> URL? {
        guard let rawValue = extractMetaContent(
            names: ["og:image", "twitter:image", "twitter:image:src"],
            in: html
        ) else {
            return nil
        }

        guard let resolved = URL(string: rawValue, relativeTo: baseURL)?.absoluteURL,
              let scheme = resolved.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return resolved
    }

    private static func extractMetaContent(names: [String], in html: String) -> String? {
        for name in names {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"<meta[^>]+(?:property|name)\s*=\s*["']\#(escapedName)["'][^>]+content\s*=\s*["']([^"']+)["'][^>]*>"#,
                #"<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+(?:property|name)\s*=\s*["']\#(escapedName)["'][^>]*>"#
            ]

            for pattern in patterns {
                if let value = captureFirstGroup(pattern: pattern, in: html) {
                    return value
                }
            }
        }
        return nil
    }

    private static func extractTagContent(tag: String, in html: String) -> String? {
        captureFirstGroup(pattern: #"<\#(tag)[^>]*>(.*?)</\#(tag)>"#, in: html)
    }

    private static func captureFirstGroup(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return normalize(String(html[valueRange]))
    }

    private static func normalize(_ text: String) -> String? {
        let stripped = text
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded.isEmpty ? nil : decoded
    }

    private static func domainLabel(for url: URL) -> String {
        let host = url.host?.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression) ?? url.absoluteString
        return host.isEmpty ? url.absoluteString : host
    }
}

struct NewsLinkPreviewCard: View {
    let urlString: String
    var accentColor: Color = RLMarkerIntent.news.color

    @Environment(\.openURL) private var openURL

    @State private var preview: NewsLinkPreview?
    @State private var isLoading = false
    @State private var didAttemptLoad = false

    var body: some View {
        let url = normalizedURL

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "newspaper.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)

                Text(preview?.domain ?? url?.host ?? "Article link")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.surfaceWhite74)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let openTarget = preview?.resolvedURL ?? url {
                    Button("Open") {
                        openURL(openTarget)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                }
            }

            if let imageURL = preview?.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surfaceWhite08)
                            ProgressView()
                                .tint(accentColor)
                        }
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let title = preview?.title {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(urlString)
                    .font(.caption)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snippet = preview?.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundColor(AppColors.surfaceWhite74)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isLoading {
                Text("Loading article preview...")
                    .font(.caption)
                    .foregroundColor(AppColors.surfaceWhite60)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.22), lineWidth: 1)
                )
        )
        .task(id: normalizedURL?.absoluteString ?? urlString) {
            await loadPreviewIfNeeded()
        }
    }

    private var normalizedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }

        if let url = URL(string: "https://\(trimmed)") {
            return url
        }

        return nil
    }

    @MainActor
    private func loadPreviewIfNeeded() async {
        guard !didAttemptLoad, !isLoading, let url = normalizedURL else { return }
        isLoading = true
        didAttemptLoad = true
        preview = await NewsLinkPreviewService.shared.preview(for: url)
        isLoading = false
    }
}
