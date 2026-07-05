//
//  ScanView.swift
//  MobileAppExpiredProducts
//

import SwiftUI

/// Full-screen camera scanner: finds an expiration date on the product,
/// asks for confirmation and stores it for the upcoming service.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScannedProductStore.self) private var store
    @StateObject private var scanner = DateScannerController()
    @State private var isShowingConfirmation = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scanner.cameraState == .running {
                CameraPreviewView(session: scanner.session)
                    .ignoresSafeArea()
            }

            detectionFrame

            if scanner.cameraState == .denied || scanner.cameraState == .unavailable {
                cameraUnavailableMessage
            }
        }
        .overlay(alignment: .top) { topBar }
        .task {
            await scanner.start()
        }
        .onDisappear {
            scanner.stop()
        }
        .onChange(of: scanner.detectedDate) { _, match in
            isShowingConfirmation = match != nil
        }
        .alert(
            "Expiration date detected",
            isPresented: $isShowingConfirmation,
            presenting: scanner.detectedDate
        ) { match in
            Button("Confirm") {
                store.add(rawText: match.rawText, expirationDate: match.date)
                dismiss()
            }
            Button("Scan again", role: .cancel) {
                scanner.resumeScanning()
            }
        } message: { match in
            Text("\(match.date.formatted(date: .long, time: .omitted))\nRead as \u{201C}\(match.rawText)\u{201D}")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title2.weight(.semibold))
            }

            Spacer()

            Text("Scan")
                .font(.headline)

            Spacer()

            Button {
                scanner.toggleTorch()
            } label: {
                Image(systemName: scanner.isTorchOn ? "bolt.fill" : "bolt")
                    .font(.title2)
            }
            .disabled(scanner.cameraState != .running || !scanner.hasTorch)

            Button {
                // Help is out of scope for now; icon kept to match the design.
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
            }
            .padding(.leading, 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var detectionFrame: some View {
        VStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white, lineWidth: 2)
                .frame(height: 180)
                .overlay {
                    Text("Point at the expiration date")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.top, 140)
            Spacer()
        }
    }

    private var cameraUnavailableMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
            Text(
                scanner.cameraState == .denied
                    ? "Camera access is denied. Enable it in Settings to scan products."
                    : "The camera is not available on this device."
            )
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

#Preview {
    ScanView()
        .environment(ScannedProductStore())
}
