# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Litter Picker is an iOS mobile app for coordinating litter picking activities. The goal is to reach MVP and publish to the App Store, with Android support planned for later.

## Status

Active development. All Phase 1–8 code is written. Requires Firebase project setup before running on a real device.

## Build Commands

```bash
# Generate Xcode project from project.yml (run after editing project.yml)
xcodegen generate

# Resolve Swift Package Manager dependencies
xcodebuild -resolvePackageDependencies -project LitterPicker.xcodeproj -scheme LitterPicker

# Build for simulator
xcodebuild -project LitterPicker.xcodeproj -scheme LitterPicker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build for device (requires signing setup)
xcodebuild -project LitterPicker.xcodeproj -scheme LitterPicker \
  -destination 'generic/platform=iOS' build
```

## Architecture

| Decision | Choice |
|---|---|
| Platform | iOS 17+ (SwiftUI) |
| UI pattern | MVVM with `@Observable` services injected via SwiftUI environment |
| Backend | Firebase (Firestore + Auth + Storage) |
| Maps | MapKit (SwiftUI `Map` API) |
| Local storage | SwiftData (`ActiveCleanup` model) |
| Auth | Anonymous-first → Sign in with Apple |
| Geo queries | Geohash prefix range queries (precision 5 for cleanups, 6 for reports) |
| Route encoding | Google Polyline Algorithm (`PolylineEncoder.swift`) |

## Project Structure

```
LitterPicker/
├── App/                    # Entry point, RootView
├── Features/
│   ├── Onboarding/         # First-launch screen
│   ├── Map/                # Home map + tab container
│   ├── Cleanup/            # Live tracking + post-cleanup flow
│   ├── Report/             # Bulky item reporting
│   └── Profile/            # Stats + sign-in prompt
├── Models/                 # ActiveCleanup (SwiftData), Cleanup, Report, AppUser
├── Services/               # AuthService, LocationService, CleanupService,
│                           # MapService, ReportService, UserService
└── Utilities/              # GeohashUtility, PolylineEncoder, RouteOpacity,
                            # DistanceFormatter, Constants
```

## Firebase Setup (required before first run)

1. Create a Firebase project at https://console.firebase.google.com/
2. Add an iOS app with bundle ID `com.litterpicker.app`
3. Download `GoogleService-Info.plist` and replace `LitterPicker/GoogleService-Info.plist`
4. Enable **Anonymous** and **Sign in with Apple** auth providers
5. Create a Firestore database; deploy rules from `firestore.rules`:
   ```bash
   firebase deploy --only firestore:rules
   ```
6. Enable Firebase Storage

## Xcode Setup

- Set your Development Team in Xcode project settings
- Enable "Sign in with Apple" capability in the Apple Developer portal for your bundle ID
- The `LitterPicker.entitlements` file is already configured

## Key Implementation Notes

- Services are `@Observable` and injected as SwiftUI environment values from `LitterPickerApp`
- `ActiveCleanup` is a SwiftData model; all other models are plain structs
- `MapService` maintains a session-scoped geohash tile cache (cleared on relaunch)
- Own routes: anonymous users read from SwiftData; authenticated users fetch via dedicated Firestore query
- Retroactive sync on sign-in uploads all `isFinalized == true && isSynced == false` records
