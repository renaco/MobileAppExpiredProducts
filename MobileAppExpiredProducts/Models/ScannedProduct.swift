//
//  ScannedProduct.swift
//  MobileAppExpiredProducts
//

import Foundation

/// A product expiration date captured by the scanner, kept in memory
/// until it is sent to the backend service.
struct ScannedProduct: Identifiable, Equatable {
    let id = UUID()
    /// The text exactly as it was read from the packaging, e.g. "EXP 12/08/2026".
    var rawText: String
    /// The parsed expiration date.
    var expirationDate: Date
    /// When the scan happened.
    let scannedAt: Date

    var formattedExpirationDate: String {
        expirationDate.formatted(date: .abbreviated, time: .omitted)
    }
}
