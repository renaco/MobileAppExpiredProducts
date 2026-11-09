//
//  ExpirationDateDetectorTests.swift
//  MobileAppExpiredProductsTests
//

import Foundation
import Testing
@testable import MobileAppExpiredProducts

struct ExpirationDateDetectorTests {
    private let detector = ExpirationDateDetector()
    private let calendar = Calendar(identifier: .gregorian)

    private func components(_ date: Date) -> (day: Int, month: Int, year: Int) {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        return (parts.day!, parts.month!, parts.year!)
    }

    @Test func detectsDayFirstNumericDate() throws {
        let match = try #require(detector.expirationDate(in: "EXP 12/08/2026"))
        #expect(match.rawText == "EXP 12/08/2026")
        #expect(components(match.date) == (12, 8, 2026))
    }

    @Test func detectsTwoDigitYearAndDotSeparators() throws {
        let match = try #require(detector.expirationDate(in: "CAD 05.11.27"))
        #expect(components(match.date) == (5, 11, 2027))
    }

    @Test func detectsYearFirstDate() throws {
        let match = try #require(detector.expirationDate(in: "2026-08-12"))
        #expect(components(match.date) == (12, 8, 2026))
    }

    @Test func detectsMonthYearAsEndOfMonth() throws {
        let match = try #require(detector.expirationDate(in: "BEST BEFORE 02/2027"))
        #expect(components(match.date) == (28, 2, 2027))
    }

    @Test func detectsSpaceSeparatedMonthYearAsEndOfMonth() throws {
        let match = try #require(detector.expirationDate(in: "EXP 08 2026"))
        #expect(match.rawText == "EXP 08 2026")
        #expect(components(match.date) == (31, 8, 2026))
    }

    @Test func rejectsSpaceSeparatedMonthYearWithTwoDigitYear() {
        // "08 26" is too ambiguous (lot codes, weights) to treat as a date.
        #expect(detector.expirationDate(in: "LOT 08 26") == nil)
    }

    @Test func detectsNamedMonths() throws {
        let english = try #require(detector.expirationDate(in: "EXP 12 AUG 2026"))
        #expect(components(english.date) == (12, 8, 2026))

        let spanish = try #require(detector.expirationDate(in: "CONSUMIR ANTES DE AGO 2026"))
        #expect(components(spanish.date) == (31, 8, 2026))
    }

    @Test func skipsInvalidDateAndFindsValidOne() throws {
        let match = try #require(detector.expirationDate(in: "LOT 31/02/2026 EXP 15/03/2026"))
        #expect(components(match.date) == (15, 3, 2026))
    }

    // MARK: - EXP marker

    @Test func prefersExpDateOverManufacturingDate() throws {
        // Two-line can label: MFG comes first, EXP must win.
        let text = "MFG:27.08.2025 YYV YT\nEXP:27.02.2027 AAA 18:33"
        let match = try #require(detector.expirationDate(in: text))
        #expect(match.rawText == "EXP:27.02.2027")
        #expect(components(match.date) == (27, 2, 2027))
    }

    @Test func prefersExpDateOnSameLine() throws {
        let match = try #require(detector.expirationDate(in: "MFG 01/01/2026 EXP 01/01/2028"))
        #expect(match.rawText == "EXP 01/01/2028")
        #expect(components(match.date) == (1, 1, 2028))
    }

    @Test(arguments: [
        "EXP:27.02.2027", "EXP.27.02.2027", "EXP 27.02.2027", "exp:27.02.2027",
        "EXP;27.02.2027", "EXPIRY 27.02.2027", "EXP DATE: 27.02.2027", "EXP.:27.02.2027",
    ])
    func acceptsExpMarkerVariants(text: String) throws {
        let match = try #require(detector.expirationDate(in: text))
        #expect(components(match.date) == (27, 2, 2027))
    }

    @Test func acceptsExpMarkerAndDateOnSeparateLines() throws {
        let match = try #require(detector.expirationDate(in: "MFG 27.08.2025\nEXP\n27.02.2027"))
        #expect(match.rawText == "EXP 27.02.2027")
        #expect(components(match.date) == (27, 2, 2027))
    }

    @Test func skipsManufacturingDateWhenNoExpMarker() throws {
        // OCR misread "EXP" — still must not pick the MFG date.
        let match = try #require(detector.expirationDate(in: "MFG:27.08.2025\nEKP:27.02.2027"))
        #expect(components(match.date) == (27, 2, 2027))
    }

    @Test func returnsNilWhenOnlyManufacturingDate() {
        #expect(detector.expirationDate(in: "MFG:27.08.2025") == nil)
        #expect(detector.expirationDate(in: "LOT 12/2026") == nil)
    }

    @Test func ignoresWordsStartingWithExp() throws {
        let match = try #require(detector.expirationDate(in: "EXPORT 01/01/2026 BB 05/05/2027"))
        // "EXPORT" is not an expiry marker; falls back to the first date.
        #expect(components(match.date) == (1, 1, 2026))
    }

    @Test func rejectsTextWithoutDates() {
        #expect(detector.expirationDate(in: "NET WT 500G LOT A123456") == nil)
        #expect(detector.expirationDate(in: "") == nil)
        #expect(detector.expirationDate(in: "99/99/9999") == nil)
    }
}
