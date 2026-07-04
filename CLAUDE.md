# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SwiftUI iOS app generated from the default Xcode "App" template — currently just the boilerplate `ContentView` (a globe icon + "Hello, world!"). No app-specific logic has been written yet; the name "ExpiredProducts" describes intended functionality that does not exist in code.

- Language: Swift 5.0, SwiftUI lifecycle (`@main` `App` in `MobileAppExpiredProductsApp.swift`)
- Deployment target: iOS 18.1
- Bundle ID prefix: `RomeroRuiz.`
- No external dependencies (no SPM/CocoaPods/Carthage), no `.xcworkspace` — open the `.xcodeproj` directly.

## Targets

Three targets, no shared schemes (Xcode auto-generates the `MobileAppExpiredProducts` scheme on first open):

- `MobileAppExpiredProducts` — the app
- `MobileAppExpiredProductsTests` — unit tests, use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest
- `MobileAppExpiredProductsUITests` — UI tests, use **XCUITest** (`import XCTest`, `XCUIApplication`)

## Build & test

Run from the `MobileAppExpiredProducts/` directory that contains the `.xcodeproj`.

```bash
# Build for simulator
xcodebuild -project MobileAppExpiredProducts.xcodeproj \
  -scheme MobileAppExpiredProducts \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -project MobileAppExpiredProducts.xcodeproj \
  -scheme MobileAppExpiredProducts \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test (Swift Testing / XCTest both use -only-testing)
xcodebuild ... test \
  -only-testing:MobileAppExpiredProductsTests/MobileAppExpiredProductsTests/example
```

`GENERATE_INFOPLIST_FILE = YES` — there is no hand-edited `Info.plist`; app metadata (permissions, display name, etc.) is set via build settings / the target's Info tab, not a plist file.
