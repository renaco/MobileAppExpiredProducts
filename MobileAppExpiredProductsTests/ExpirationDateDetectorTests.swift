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
        let match = try #require(detector.firstDate(in: "EXP 12/08/2026"))
        #expect(match.rawText == "12/08/2026")
        #expect(components(match.date) == (12, 8, 2026))
    }

    @Test func detectsTwoDigitYearAndDotSeparators() throws {
        let match = try #require(detector.firstDate(in: "CAD 05.11.27"))
        #expect(components(match.date) == (5, 11, 2027))
    }

    @Test func detectsYearFirstDate() throws {
        let match = try #require(detector.firstDate(in: "2026-08-12"))
        #expect(components(match.date) == (12, 8, 2026))
    }

    @Test func detectsMonthYearAsEndOfMonth() throws {
        let match = try #require(detector.firstDate(in: "BEST BEFORE 02/2027"))
        #expect(components(match.date) == (28, 2, 2027))
    }

    @Test func detectsNamedMonths() throws {
        let english = try #require(detector.firstDate(in: "EXP 12 AUG 2026"))
        #expect(components(english.date) == (12, 8, 2026))

        let spanish = try #require(detector.firstDate(in: "CONSUMIR ANTES DE AGO 2026"))
        #expect(components(spanish.date) == (31, 8, 2026))
    }

    @Test func skipsInvalidDateAndFindsValidOne() throws {
        let match = try #require(detector.firstDate(in: "LOT 31/02/2026 EXP 15/03/2026"))
        #expect(components(match.date) == (15, 3, 2026))
    }

    @Test func rejectsTextWithoutDates() {
        #expect(detector.firstDate(in: "NET WT 500G LOT A123456") == nil)
        #expect(detector.firstDate(in: "") == nil)
        #expect(detector.firstDate(in: "99/99/9999") == nil)
    }
}
