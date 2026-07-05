//
//  ContentView.swift
//  MobileAppExpiredProducts
//
//  Created by Renan Romero Ruiz on 4/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ScannedProductStore.self) private var store
    @State private var isShowingScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchBarView {
                isShowingScanner = true
            }
            FilterChipsView()

            if !store.pendingScans.isEmpty {
                pendingScansList
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(.systemGray6))
        .fullScreenCover(isPresented: $isShowingScanner) {
            ScanView()
        }
    }

    /// Scans waiting to be sent to the service, shown so the temporary
    /// storage is visible while the service integration is pending.
    private var pendingScansList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pending scans")
                .font(.headline)
                .padding(.top, 16)

            ForEach(store.pendingScans) { scan in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scan.formattedExpirationDate)
                            .font(.body.weight(.medium))
                        Text("Read as \u{201C}\(scan.rawText)\u{201D}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        store.remove(scan)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(ScannedProductStore())
}
