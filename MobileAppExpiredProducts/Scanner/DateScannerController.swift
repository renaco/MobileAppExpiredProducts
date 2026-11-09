//
//  DateScannerController.swift
//  MobileAppExpiredProducts
//

import AVFoundation
import Vision

/// Runs the camera session, feeds frames to Vision text recognition and
/// publishes the first text that looks like an expiration date.
final class DateScannerController: NSObject, ObservableObject {
    enum CameraState {
        case idle
        case running
        case denied
        case unavailable
    }

    @Published var cameraState: CameraState = .idle
    @Published var detectedDate: ExpirationDateDetector.Match?
    @Published var isTorchOn = false
    /// Set when a manually captured frame contained no recognizable date.
    @Published var captureFoundNoDate = false

    let session = AVCaptureSession()

    private let detector = ExpirationDateDetector()
    private let sessionQueue = DispatchQueue(label: "date-scanner.session")
    private let videoOutputQueue = DispatchQueue(label: "date-scanner.video-output")
    private var videoDevice: AVCaptureDevice?
    private var isConfigured = false
    /// Skips analysis while a frame is in flight or a detection awaits confirmation.
    private var isAnalysisPaused = false
    private var isProcessingFrame = false
    /// Set when the user taps the shutter button; the next frame reports
    /// back even when no date is found in it.
    private var isManualCapture = false

    var hasTorch: Bool { videoDevice?.hasTorch ?? false }

    // MARK: - Lifecycle

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                await MainActor.run { cameraState = .denied }
                return
            }
        case .authorized:
            break
        default:
            await MainActor.run { cameraState = .denied }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let configured = self.configureSessionIfNeeded()
            if configured {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.cameraState = configured ? .running : .unavailable
            }
        }
    }

    func stop() {
        setTorch(enabled: false)
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Detection flow

    /// Called after the user dismisses the confirmation alert choosing to keep scanning.
    func resumeScanning() {
        detectedDate = nil
        videoOutputQueue.async { [weak self] in
            self?.isAnalysisPaused = false
        }
    }

    /// Analyzes the next camera frame on demand, reporting back through
    /// `captureFoundNoDate` when it contains no recognizable date.
    func capturePhoto() {
        videoOutputQueue.async { [weak self] in
            self?.isManualCapture = true
        }
    }

    // MARK: - Torch

    func toggleTorch() {
        setTorch(enabled: !isTorchOn)
    }

    private func setTorch(enabled: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = enabled
        } catch {
            // Torch is a nice-to-have; ignore configuration failures.
        }
    }

    // MARK: - Session setup

    private func configureSessionIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .high
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)
        session.commitConfiguration()

        videoDevice = device
        isConfigured = true
        return true
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DateScannerController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isAnalysisPaused, !isProcessingFrame,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        isProcessingFrame = true

        let request = VNRecognizeTextRequest { [weak self] request, _ in
            self?.handleRecognizedText(request: request)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right // portrait UI with the back camera
        )
        do {
            try handler.perform([request])
        } catch {
            isProcessingFrame = false
        }
    }

    private func handleRecognizedText(request: VNRequest) {
        let wasManualCapture = isManualCapture
        isManualCapture = false
        defer { isProcessingFrame = false }
        guard !isAnalysisPaused,
              let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            if let match = detector.firstDate(in: candidate.string) {
                isAnalysisPaused = true
                DispatchQueue.main.async { [weak self] in
                    self?.detectedDate = match
                }
                return
            }
        }

        if wasManualCapture {
            DispatchQueue.main.async { [weak self] in
                self?.captureFoundNoDate = true
            }
        }
    }
}
