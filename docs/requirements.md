# Mobile App Expired Products – Development Requirements

## Overview

This document outlines the five core features implemented for the Expired Products scanner app, along with step-by-step development instructions and architecture notes.

---

## Requirement 1: Search Bar Activation (Camera Only)

### Description
The home screen displays a search bar that does not accept text input. Tapping anywhere on the search bar opens the full-screen camera scanner.

### Implementation Details
- **File**: [`MobileAppExpiredProducts/Views/SearchBarView.swift`](MobileAppExpiredProducts/Views/SearchBarView.swift)
- **Design**: Capsule-shaped input field with:
  - Magnifying glass icon
  - Placeholder text: "Search or ask a question"
  - Camera and microphone icons on the right
- **Interaction**: `onTapGesture` triggers the camera scanner (via `onCameraTap` callback)
- **Additional UI**: `FilterChipsView` displays static filter chips (33463 location, Video, Deals, Grocery)

### Development Steps
1. Create a `SearchBarView` struct that renders a capsule-shaped button
2. Add the search placeholder text and icons (magnifier, camera, mic)
3. Add an `onCameraTap` callback parameter
4. Attach `onTapGesture` to the entire view to trigger the callback
5. Mark the view as accessible: `accessibilityLabel` and `accessibilityAddTraits(.isButton)`
6. Create `FilterChipsView` to render the horizontal chip row below the search bar
7. Integrate both into `ContentView` and pass the camera trigger callback

---

## Requirement 2: Camera Text Detection (Date Format)

### Description
The scanner uses the device camera to capture frames, applies Vision text recognition, and filters for expiration-date patterns.

### Supported Date Formats
- **Numeric (day first)**: `12/08/2026`, `12-08-26`, `12.08.2026`
- **Numeric (year first)**: `2026-08-12`
- **Month/Year only**: `08/2026`, `08/26` → parsed as the **last day of that month**
- **Named months**: `12 AUG 2026`, `12 AGO 2026` (English and Spanish abbreviations)
- **Separators**: `/`, `-`, `.`, or space

### Invalid Dates Rejected
Impossible dates like `31/02/2026` are rejected instead of rolling over.

### Implementation Details

#### ExpirationDateDetector
- **File**: [`MobileAppExpiredProducts/Scanner/ExpirationDateDetector.swift`](MobileAppExpiredProducts/Scanner/ExpirationDateDetector.swift)
- Core logic: three regex patterns (numeric full date, named month, month-year)
- Method: `firstDate(in:)` returns a `Match` (raw text + parsed `Date`) or nil
- Iterates through all regex matches to handle multiple dates on packaging

#### DateScannerController
- **File**: [`MobileAppExpiredProducts/Scanner/DateScannerController.swift`](MobileAppExpiredProducts/Scanner/DateScannerController.swift)
- Manages AVFoundation session, camera permissions, and Vision text recognition
- Publishes `@Published var detectedDate` when a valid date is found
- Pauses analysis (`isAnalysisPaused`) while waiting for user confirmation
- Published state: `cameraState` (.idle, .running, .denied, .unavailable)

#### CameraPreviewView
- **File**: [`MobileAppExpiredProducts/Scanner/CameraPreviewView.swift`](MobileAppExpiredProducts/Scanner/CameraPreviewView.swift)
- UIViewRepresentable wrapper around `AVCaptureVideoPreviewLayer`
- Displays the live camera feed in SwiftUI

### Development Steps

1. **Create ExpirationDateDetector**
   - Define three regex patterns for date formats
   - Build a month-abbreviation dictionary (English + Spanish)
   - Implement `firstDate(in:)` that tries each pattern in order
   - Add date component parsing and validation
   - Handle 2-digit years (assume 20xx)
   - For month-only dates, calculate the last day of the month

2. **Create DateScannerController**
   - Conform to `ObservableObject` and `AVCaptureVideoDataOutputSampleBufferDelegate`
   - Implement `start()` (request camera permission, configure session)
   - Implement `stop()` (stop running, turn off torch)
   - Wire up `AVCaptureSession` with back wide-angle camera, high preset
   - Add `VNRecognizeTextRequest` handler in `captureOutput(_:didOutput:from:)`
   - Feed recognized text to `ExpirationDateDetector`
   - Publish detected dates via `@Published var detectedDate`
   - Add `resumeScanning()` to unpause analysis after confirmation

3. **Create CameraPreviewView**
   - Implement `UIViewRepresentable` with a custom `UIView` subclass
   - Override `layerClass` to return `AVCaptureVideoPreviewLayer`
   - Attach the session to the preview layer

---

## Requirement 3: Confirmation Alert

### Description
When a date is detected, scanning pauses and an alert appears showing the parsed date and the raw text recognized from the packaging. The user can confirm or scan again.

### Implementation Details
- **File**: [`MobileAppExpiredProducts/Views/ScanView.swift`](MobileAppExpiredProducts/Views/ScanView.swift)
- Uses SwiftUI's `.alert()` modifier
- Alert title: "Expiration date detected"
- Message: formatted date + raw text in quotes (e.g., "August 12, 2026\nRead as "EXP 12 AUG 2026"")
- **Confirm** button: saves to store and dismisses the scanner
- **Scan again** button: calls `resumeScanning()` to reset state

### Development Steps
1. Add a `@State` var `isShowingConfirmation` to track alert visibility
2. Use `.onChange(of: scanner.detectedDate)` to show the alert when a date is found
3. Use `.alert()` modifier with `presenting: scanner.detectedDate`
4. On confirm, call `store.add(rawText:expirationDate:)` and dismiss the view
5. On cancel, call `scanner.resumeScanning()` to unpause the video feed

---

## Requirement 4: Torch/Light Toggle

### Description
The camera scanner displays a flashlight icon in the top toolbar. Tapping it toggles the device torch on/off. The button is disabled if the device lacks a torch (e.g., simulator).

### Implementation Details
- **File**: [`MobileAppExpiredProducts/Views/ScanView.swift`](MobileAppExpiredProducts/Views/ScanView.swift) (top bar)
- **File**: [`MobileAppExpiredProducts/Scanner/DateScannerController.swift`](MobileAppExpiredProducts/Scanner/DateScannerController.swift) (torch control)
- Published state: `@Published var isTorchOn`
- Property: `hasTorch` checks device capability
- Method: `toggleTorch()` switches the torch mode
- Torch mode set via `AVCaptureDevice.lockForConfiguration()` and `torchMode = .on/.off`

### Development Steps
1. Add `@Published var isTorchOn = false` to `DateScannerController`
2. Add property `var hasTorch: Bool { videoDevice?.hasTorch ?? false }`
3. Implement `toggleTorch()` method:
   - Check device has torch
   - Lock configuration
   - Set `torchMode` to `.on` or `.off`
   - Update published state
   - Unlock configuration (errors ignored—torch is a nice-to-have)
4. In `ScanView`, add a bolt icon button that:
   - Calls `scanner.toggleTorch()` on tap
   - Displays filled bolt if `isTorchOn`, outline if off
   - Is disabled when `cameraState != .running` or `!scanner.hasTorch`

---

## Requirement 5: Temporary Storage (Ready for Service)

### Description
Confirmed scans are stored in memory in a `ScannedProductStore`. The store is ready to send to a backend service via `sendPendingScans()` (stub awaiting service implementation). Pending scans are visible on the home screen for transparency.

### Implementation Details

#### ScannedProduct
- **File**: [`MobileAppExpiredProducts/Models/ScannedProduct.swift`](MobileAppExpiredProducts/Models/ScannedProduct.swift)
- Properties:
  - `id`: UUID for tracking
  - `rawText`: text as recognized from packaging
  - `expirationDate`: parsed `Date`
  - `scannedAt`: timestamp
- Helper: `formattedExpirationDate` returns a readable string

#### ScannedProductStore
- **File**: [`MobileAppExpiredProducts/Models/ScannedProductStore.swift`](MobileAppExpiredProducts/Models/ScannedProductStore.swift)
- Marked `@Observable` and `@MainActor`
- Stores `pendingScans: [ScannedProduct]`
- Methods:
  - `add(rawText:expirationDate:)` — creates and inserts new scan at front of list
  - `remove(_:)` — removes scan by ID
  - `sendPendingScans()` — async stub for future service integration

#### ContentView Integration
- Displays "Pending scans" section if any exist
- Each scan shows:
  - Formatted expiration date
  - Raw text as recognized
  - Delete button
- Injects `ScannedProductStore` as environment object

#### App-Level Setup
- **File**: [`MobileAppExpiredProducts/MobileAppExpiredProductsApp.swift`](MobileAppExpiredProducts/MobileAppExpiredProductsApp.swift)
- Creates `@State private var scannedProductStore = ScannedProductStore()`
- Passes it to `ContentView` via `.environment(scannedProductStore)`

### Development Steps

1. **Create ScannedProduct model**
   - Define `Identifiable` struct with UUID id
   - Add properties: `rawText`, `expirationDate`, `scannedAt`
   - Add computed property `formattedExpirationDate`

2. **Create ScannedProductStore**
   - Mark as `@Observable` and `@MainActor`
   - Add `@Published` or direct property `pendingScans: [ScannedProduct]`
   - Implement `add(rawText:expirationDate:)`:
     - Create `ScannedProduct` with `scannedAt: .now`
     - Insert at index 0 (most recent first)
   - Implement `remove(_:)` to delete by ID
   - Add stub `sendPendingScans() async throws` with TODO comment

3. **Update ContentView**
   - Add `@Environment(ScannedProductStore.self) private var store`
   - In the main VStack, add a "Pending scans" section that:
     - Only displays if `!store.pendingScans.isEmpty`
     - Iterates over scans with `ForEach`
     - Renders each as a card with formatted date, raw text, and delete button

4. **Update MobileAppExpiredProductsApp**
   - Create `@State var scannedProductStore = ScannedProductStore()`
   - Pass to `ContentView` with `.environment(scannedProductStore)`

---

## ScanView: Full-Screen Camera

### File
[`MobileAppExpiredProducts/Views/ScanView.swift`](MobileAppExpiredProducts/Views/ScanView.swift)

### Structure
- **Background**: black full screen with camera preview
- **Top bar**: back button, "Scan" title, torch button, help button (icon only for now)
- **Detection frame**: white rounded rectangle overlay with instruction text ("Point at the expiration date")
- **Alert**: confirmation dialog when a date is detected
- **Camera unavailable**: error message if permission denied or no camera

### Task Lifecycle
1. On appear: calls `scanner.start()` to begin session and request permissions
2. On disappear: calls `scanner.stop()` to clean up
3. On detected date: shows confirmation alert
4. Confirm: saves to store and dismisses the scanner
5. Scan again: resumes video feed and clears detected date

---

## Project Configuration

### Info.plist Keys
- **Camera usage**: `NSCameraUsageDescription` → "The camera is used to scan product expiration dates."
  - Added automatically to generated Info.plist via Xcode build settings

### Deployment
- **Target**: iOS 18.1+
- **Device families**: iPhone and iPad
- **Architectures**: arm64 and x86_64 (simulator)

---

## Testing

### Unit Tests
- **File**: [`MobileAppExpiredProductsTests/ExpirationDateDetectorTests.swift`](MobileAppExpiredProductsTests/ExpirationDateDetectorTests.swift)
- **Test cases** (all passing):
  - `detectsDayFirstNumericDate()` — validates `12/08/2026` parsing
  - `detectsTwoDigitYearAndDotSeparators()` — validates `05.11.27`
  - `detectsYearFirstDate()` — validates `2026-08-12`
  - `detectsMonthYearAsEndOfMonth()` — validates `02/2027` → Feb 28
  - `detectsNamedMonths()` — validates English and Spanish month abbreviations
  - `skipsInvalidDateAndFindsValidOne()` — validates robustness to multiple dates
  - `rejectsTextWithoutDates()` — validates rejection of invalid input

### Manual Testing
1. Run on physical device (simulator has no camera)
2. Tap the search bar to open the scanner
3. Point at product packaging with an expiration date
4. Confirm the detected date or scan again
5. Check the home screen to see pending scans
6. Test torch toggle (on physical device)
7. Test delete from pending scans

---

## Future Work

### Service Integration
- Replace `ScannedProductStore.sendPendingScans()` stub with actual HTTP client
- Remove scans from pending list after successful submission
- Add error handling and retry logic

### UI Enhancements
- Help screen (activate the `?` button)
- Search text input (currently unused)
- Mic input (currently unused)
- Analytics for scan success rates

### Date Detection
- Support additional formats (e.g., Julian dates)
- Confidence scoring for ambiguous matches
- ML model for improved OCR accuracy

---

## Known Limitations

- **No persistence**: Scans are lost when the app closes (in-memory only)
- **Simulator limitation**: No camera feed on simulator; home screen and confirmation flow work, but end-to-end scanning requires a physical device
- **Ambiguous dates**: Numeric dates are read day-first (DD/MM/YYYY), not US format (MM/DD/YYYY)
- **Help & search**: Placeholder buttons not yet wired up
