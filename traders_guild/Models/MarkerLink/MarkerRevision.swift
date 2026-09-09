//
//  MarkerRevision.swift
//  traders_guild
//
//  Microsecond-exact ordering for response-count revisions.
//
//  `Date` cannot carry these. Foundation's `ISO8601DateFormatter` truncates the
//  fractional part to milliseconds, so `...10:00:00.123001+00:00` and
//  `...10:00:00.123002+00:00` decode to the *same* `Date`. The backend advances
//  a parent's revision by microseconds under a row lock, which means two
//  genuinely different revisions would compare equal and a real count change
//  would be discarded as already-seen.
//
//  So revisions are never modelled as `Date`. They are parsed straight from the
//  wire string into integer microseconds since the epoch, which is exact,
//  totally ordered, and free of any formatter's rounding.
//

import Foundation

/// An instant on the revision timeline, exact to the microsecond.
struct MarkerRevision: Comparable, Hashable, Codable, CustomStringConvertible {

    /// Microseconds since 1970-01-01T00:00:00Z. Signed so pre-epoch values,
    /// which should never occur, cannot wrap into the future.
    let microsecondsSinceEpoch: Int64

    /// Exactly what the server sent, kept so a locally patched marker can carry
    /// the server's own spelling back rather than a re-rendered approximation.
    ///
    /// Deliberately excluded from equality and ordering: two spellings of one
    /// instant are the same revision.
    let wireText: String?

    init(microsecondsSinceEpoch: Int64, wireText: String? = nil) {
        self.microsecondsSinceEpoch = microsecondsSinceEpoch
        self.wireText = wireText
    }

    static func == (lhs: MarkerRevision, rhs: MarkerRevision) -> Bool {
        lhs.microsecondsSinceEpoch == rhs.microsecondsSinceEpoch
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(microsecondsSinceEpoch)
    }

    // MARK: - Wire parsing

    /// Parse an ISO-8601 timestamp without losing sub-millisecond precision.
    ///
    /// Accepts the shapes the backend actually emits — `Z` or a numeric offset,
    /// with or without a fractional part, and any fractional length — and does
    /// the arithmetic itself rather than going through a formatter, because
    /// every Foundation formatter on this path rounds to milliseconds.
    init?(wire raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Split date and time on the designator.
        let parts = text.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let dateComponents = parts[0].split(separator: "-", omittingEmptySubsequences: false)
        guard dateComponents.count == 3,
              let year = Int(dateComponents[0]),
              let month = Int(dateComponents[1]),
              let day = Int(dateComponents[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }

        var timeText = String(parts[1])
        var offsetSeconds = 0

        // Trailing zone: `Z`, `+HH:MM`, `-HHMM`, or absent (treated as UTC).
        if timeText.hasSuffix("Z") || timeText.hasSuffix("z") {
            timeText.removeLast()
        } else if let signIndex = timeText.lastIndex(where: { $0 == "+" || $0 == "-" }),
                  signIndex > timeText.startIndex {
            let zone = String(timeText[timeText.index(after: signIndex)...])
            let sign = timeText[signIndex] == "-" ? -1 : 1
            let digits = zone.replacingOccurrences(of: ":", with: "")
            guard digits.count == 4 || digits.count == 2,
                  let hours = Int(digits.prefix(2)) else { return nil }
            let minutes = digits.count == 4 ? Int(digits.suffix(2)) ?? 0 : 0
            offsetSeconds = sign * (hours * 3600 + minutes * 60)
            timeText = String(timeText[..<signIndex])
        }

        // Fractional part, kept as digits so it can be scaled exactly.
        var fractionDigits = ""
        if let dot = timeText.firstIndex(of: ".") {
            fractionDigits = String(timeText[timeText.index(after: dot)...])
            timeText = String(timeText[..<dot])
            guard fractionDigits.allSatisfy(\.isNumber) else { return nil }
        }

        let clock = timeText.split(separator: ":", omittingEmptySubsequences: false)
        guard clock.count >= 2,
              let hour = Int(clock[0]),
              let minute = Int(clock[1]) else {
            return nil
        }
        let second = clock.count > 2 ? Int(clock[2]) ?? 0 : 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second) else {
            return nil
        }

        // Pad or truncate to exactly six digits of microseconds. Truncation
        // only ever discards precision finer than the backend emits.
        let normalizedFraction = String((fractionDigits + "000000").prefix(6))
        guard let microsecondPart = Int64(normalizedFraction) else { return nil }

        let days = Int64(Self.daysFromCivil(year: year, month: month, day: day))
        let secondsOfDay = Int64(hour * 3600 + minute * 60 + second - offsetSeconds)
        let totalSeconds = days * 86_400 + secondsOfDay

        microsecondsSinceEpoch = totalSeconds * 1_000_000 + microsecondPart
        wireText = text
    }

    /// Days from 1970-01-01 for a proleptic Gregorian date.
    ///
    /// Hinnant's civil-from-days inverse: pure integer arithmetic, so it cannot
    /// introduce the rounding this type exists to avoid.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        var y = year
        y -= month <= 2 ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    // MARK: - Interop

    /// Lossy on purpose: only for display and for legacy call sites that still
    /// speak `Date`. Never use it for ordering.
    var approximateDate: Date {
        Date(timeIntervalSince1970: Double(microsecondsSinceEpoch) / 1_000_000)
    }

    var description: String {
        "MarkerRevision(\(microsecondsSinceEpoch)µs)"
    }

    static func < (lhs: MarkerRevision, rhs: MarkerRevision) -> Bool {
        lhs.microsecondsSinceEpoch < rhs.microsecondsSinceEpoch
    }

    /// Builds from an optional wire string, treating empty as absent.
    static func make(_ raw: String?) -> MarkerRevision? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return MarkerRevision(wire: raw)
    }
}
