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
        guard !text.isEmpty, text.count <= 64 else { return nil }

        let parts = text.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        // Date. Bounded to the year range Python's datetime can express, so the
        // arithmetic below cannot overflow on a hostile or corrupt value.
        let dateComponents = parts[0].split(separator: "-", omittingEmptySubsequences: false)
        guard dateComponents.count == 3,
              dateComponents.allSatisfy({ $0.allSatisfy(\.isNumber) }),
              // Zero-padded widths, as Python's isoformat always writes them.
              // Accepting "2026-9-9" would admit shapes the wire never uses.
              dateComponents[0].count == 4,
              dateComponents[1].count == 2,
              dateComponents[2].count == 2,
              let year = Int(dateComponents[0]),
              let month = Int(dateComponents[1]),
              let day = Int(dateComponents[2]),
              (1...9999).contains(year),
              (1...12).contains(month),
              day >= 1,
              day <= Self.daysInMonth(year: year, month: month) else {
            return nil
        }

        var timeText = String(parts[1])
        var offsetSeconds = 0

        // Zone: `Z`, `+HH:MM` / `-HHMM`, or absent (UTC). A missing zone is the
        // only case allowed to default; anything malformed is rejected.
        if timeText.hasSuffix("Z") || timeText.hasSuffix("z") {
            timeText.removeLast()
        } else if let signIndex = timeText.lastIndex(where: { $0 == "+" || $0 == "-" }),
                  signIndex > timeText.startIndex {
            let zone = String(timeText[timeText.index(after: signIndex)...])
            let sign = timeText[signIndex] == "-" ? -1 : 1
            let digits = zone.replacingOccurrences(of: ":", with: "")
            guard digits.allSatisfy(\.isNumber),
                  digits.count == 4 || digits.count == 2,
                  let hours = Int(digits.prefix(2)),
                  (0...23).contains(hours) else {
                return nil
            }
            let minutes: Int
            if digits.count == 4 {
                guard let parsed = Int(digits.suffix(2)), (0...59).contains(parsed) else { return nil }
                minutes = parsed
            } else {
                minutes = 0
            }
            offsetSeconds = sign * (hours * 3600 + minutes * 60)
            timeText = String(timeText[..<signIndex])
        }

        // Fraction, kept as digits so it scales exactly.
        var fractionDigits = ""
        if let dot = timeText.firstIndex(of: ".") {
            fractionDigits = String(timeText[timeText.index(after: dot)...])
            timeText = String(timeText[..<dot])
            guard !fractionDigits.isEmpty,
                  fractionDigits.count <= 12,
                  fractionDigits.allSatisfy(\.isNumber) else {
                return nil
            }
        }

        // Clock. Every component must be present, numeric and in range —
        // nothing silently defaults to zero, and a fourth component is a
        // malformed value rather than something to ignore.
        let clock = timeText.split(separator: ":", omittingEmptySubsequences: false)
        guard clock.count == 2 || clock.count == 3,
              clock.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let hour = Int(clock[0]),
              let minute = Int(clock[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        let second: Int
        if clock.count == 3 {
            guard let parsed = Int(clock[2]), (0...60).contains(parsed) else { return nil }
            second = parsed
        } else {
            second = 0
        }

        // Pad or truncate to exactly six digits of microseconds.
        let normalizedFraction = String((fractionDigits + "000000").prefix(6))
        guard let microsecondPart = Int64(normalizedFraction) else { return nil }

        let days = Int64(Self.daysFromCivil(year: year, month: month, day: day))
        let secondsOfDay = Int64(hour * 3600 + minute * 60 + second - offsetSeconds)
        let totalSeconds = days * 86_400 + secondsOfDay

        // Bounded inputs make this safe, but the multiply is still checked
        // rather than trusted: a trap here would take the app down.
        let (scaled, overflow) = totalSeconds.multipliedReportingOverflow(by: 1_000_000)
        guard !overflow else { return nil }
        let (total, addOverflow) = scaled.addingReportingOverflow(microsecondPart)
        guard !addOverflow else { return nil }

        microsecondsSinceEpoch = total
        wireText = text
    }

    /// Length of a month in the proleptic Gregorian calendar, so 31 February is
    /// rejected rather than normalised into March.
    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2:
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return isLeap ? 29 : 28
        default: return 0
        }
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
