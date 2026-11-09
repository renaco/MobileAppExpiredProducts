//
//  ExpirationDateDetector.swift
//  MobileAppExpiredProducts
//

import Foundation

/// Finds expiration dates inside text recognized on product packaging.
///
/// Supported formats (case-insensitive, "/", "-", "." or space separators):
/// - `12/08/2026`, `12-08-26`, `12.08.2026`  (day first)
/// - `2026-08-12`                            (year first)
/// - `08/2026`, `08/26`, `08 2026`           (month and year only → last day of month)
/// - `12 AUG 2026`, `AGO 2026`               (English and Spanish month abbreviations)
struct ExpirationDateDetector {
    struct Match: Equatable {
        let rawText: String
        let date: Date
    }

    private static let monthsByAbbreviation: [String: Int] = [
        // English
        "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
        "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
        // Spanish (where different)
        "ENE": 1, "ABR": 4, "AGO": 8, "DIC": 12,
    ]

    private static let numericFullPattern =
        /(?<first>\d{1,4})[\/\-\.](?<second>\d{1,2})[\/\-\.](?<third>\d{1,4})/
    private static let numericMonthYearPattern =
        /(?<month>\d{1,2})[\/\-\.](?<year>\d{2}|\d{4})(?!\d)/
    /// "MM YYYY": space separator requires a four-digit year so that plain
    /// number pairs (lot codes, weights) are not mistaken for dates.
    private static let numericMonthSpaceYearPattern =
        /\b(?<month>\d{1,2}) (?<year>\d{4})(?!\d)/
    private static let namedMonthPattern =
        /(?i)(?:(?<day>\d{1,2})[ \/\-\.])?\b(?<month>JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|ENE|ABR|AGO|DIC)[A-Za-z]*[ \/\-\.]?(?<year>\d{2}|\d{4})(?!\d)/

    private let calendar = Calendar(identifier: .gregorian)

    /// Returns the first valid expiration date found in `text`, or nil.
    func firstDate(in text: String) -> Match? {
        for match in text.matches(of: Self.numericFullPattern) {
            if let date = date(first: Int(match.first), second: Int(match.second), third: Int(match.third)) {
                return Match(rawText: String(match.0), date: date)
            }
        }
        for match in text.matches(of: Self.namedMonthPattern) {
            if let month = Self.monthsByAbbreviation[match.month.uppercased()],
               let year = normalizedYear(Int(match.year)),
               let date = date(day: match.day.flatMap { Int($0) }, month: month, year: year) {
                return Match(rawText: String(match.0), date: date)
            }
        }
        for match in text.matches(of: Self.numericMonthYearPattern) {
            if let month = Int(match.month), (1...12).contains(month),
               let year = normalizedYear(Int(match.year)),
               let date = date(day: nil, month: month, year: year) {
                return Match(rawText: String(match.0), date: date)
            }
        }
        for match in text.matches(of: Self.numericMonthSpaceYearPattern) {
            if let month = Int(match.month), (1...12).contains(month),
               let year = normalizedYear(Int(match.year)),
               let date = date(day: nil, month: month, year: year) {
                return Match(rawText: String(match.0), date: date)
            }
        }
        return nil
    }

    /// Interprets a three-component numeric date, trying year-first
    /// (2026-08-12) and then day-first (12/08/2026).
    private func date(first: Int?, second: Int?, third: Int?) -> Date? {
        guard let first, let second, let third else { return nil }
        if first > 999 {
            return date(day: third, month: second, year: normalizedYear(first))
        }
        return date(day: first, month: second, year: normalizedYear(third))
    }

    private func date(day: Int?, month: Int?, year: Int?) -> Date? {
        guard let month, let year, (1...12).contains(month), (2000...2099).contains(year) else {
            return nil
        }
        var components = DateComponents(year: year, month: month)
        if let day {
            guard (1...31).contains(day) else { return nil }
            components.day = day
        } else {
            // Month/year only: assume the product expires at the end of that month.
            guard let startOfMonth = calendar.date(from: components),
                  let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth) else {
                return nil
            }
            components.day = dayRange.upperBound - 1
        }
        // Reject impossible dates like 31/02/2026 instead of letting them roll over.
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == components.day,
              calendar.component(.month, from: date) == month else {
            return nil
        }
        return date
    }

    private func normalizedYear(_ year: Int?) -> Int? {
        guard let year else { return nil }
        return year < 100 ? 2000 + year : year
    }
}
