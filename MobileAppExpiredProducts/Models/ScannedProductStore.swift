//
//  ScannedProductStore.swift
//  MobileAppExpiredProducts
//

import Foundation
import Observation

/// Temporary in-memory storage for confirmed scans.
/// Scans live here until they are pushed to the backend service.
@Observable
@MainActor
final class ScannedProductStore {
    private(set) var pendingScans: [ScannedProduct] = []

    func add(rawText: String, expirationDate: Date) {
        let scan = ScannedProduct(
            rawText: rawText,
            expirationDate: expirationDate,
            scannedAt: .now
        )
        pendingScans.insert(scan, at: 0)
    }

    func remove(_ scan: ScannedProduct) {
        pendingScans.removeAll { $0.id == scan.id }
    }

    /// Sends the pending scans to the backend service.
    /// TODO: implement once the service endpoint is available; on success
    /// the sent scans should be removed from `pendingScans`.
    func sendPendingScans() async throws {
        // Placeholder for the upcoming service integration.
    }
}
