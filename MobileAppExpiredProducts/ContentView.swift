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
    @State private var editingScan: ScannedProduct?

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
        .sheet(item: $editingScan) { scan in
            EditScanView(scan: scan) { rawText, expirationDate in
                store.update(scan, rawText: rawText, expirationDate: expirationDate)
            }
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
                    Button {
                        editingScan = scan
                    } label: {
                        Image(systemName: "pencil")
                    }
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

/// Sheet for editing a pending scan's read text and expiration date.
private struct EditScanView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var rawText: String
    @State private var expirationDate: Date

    let onSave: (String, Date) -> Void

    init(scan: ScannedProduct, onSave: @escaping (String, Date) -> Void) {
        _rawText = State(initialValue: scan.rawText)
        _expirationDate = State(initialValue: scan.expirationDate)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Read text") {
                    TextField("Read text", text: $rawText)
                }
                Section("Expiration date") {
                    DatePicker(
                        "Expiration date",
                        selection: $expirationDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Edit scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(rawText, expirationDate)
                        dismiss()
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(ScannedProductStore())
}
