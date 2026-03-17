# Litter Picker — Architecture & Development Plan

## Vision

An iOS app for coordinating and logging litter picking activity. Users can record solo cleanups with live GPS tracking, report bulky items on the map, and see a community clean map where routes fade over time to reflect how recently an area was cleaned.

The community map serves a dual purpose: celebrating effort (what's been cleaned) and highlighting neglected areas (where to go next).

The app targets a global audience. Initially it will be released in English-only. Software developers are welcome to join and contribute in any way they can.

---

## Key Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Platform | iOS (SwiftUI) | Initial target; Android later |
| UI Framework | SwiftUI | Modern, aligns with Apple's direction |
| App pattern | MVVM | Clean separation, testable, standard for SwiftUI |
| Backend | Firebase | Firestore + Auth + Storage, strong iOS SDK, generous free tier |
| Maps | MapKit | Native, no cost, privacy-friendly |
| Auth | Anonymous-first, Sign in with Apple | Lower friction onboarding; Apple required for App Store social apps |
| Session storage | Local-first (SwiftData) → Firebase on completion | Protects data if app is killed mid-cleanup; avoids partial writes to Firestore |
| iOS minimum | iOS 17 | Required for SwiftData; covers ~90%+ of active devices as of 2026 |
| Visual style | Green / nature palette | Reinforces environmental theme |

---

## Auth Model

Anonymous users **can**:
- Record personal cleanups (stored on-device in SwiftData only)
- View the community clean map

Anonymous users **cannot** (sign-in prompt triggered):
- Share a completed cleanup to the community map (Firestore write)
- Submit or resolve a bulky item report

Anonymous user data (if app deleted without signing in) is lost — this is acceptable; no cascade delete is needed.

---

## Data Models

### `Cleanup`
```
id: String
userId: String               // authenticated Firebase UID — cleanups are only written to Firestore by signed-in users
startedAt: Timestamp
endedAt: Timestamp
durationSeconds: Int
distanceMeters: Double
encodedPolyline: String  // Google Polyline Encoding Algorithm
startGeohash: String     // geohash of cleanup start point, precision 5 (~5km cell), for proximity queries
bagsCollected: Int?      // optional, prompted at cleanup end
notes: String?           // optional free text, prompted at cleanup end
locationName: String?    // optional user-supplied name (e.g. "Victoria Park"), prompted at cleanup end
```

### `ActiveCleanup` *(SwiftData — on-device only)*
```
id: UUID
startedAt: Date
coordinatesData: Data    // serialised [CLLocationCoordinate2D] — stored as flat [Double] (lat, lon pairs)
                         // encoded/decoded by CleanupService; CLLocationCoordinate2D is not directly SwiftData-compatible
distanceMeters: Double   // running total, updated on each location update
isSynced: Bool           // false until successfully written to Firestore on cleanup end
endedAt: Date?           // set on Stop Cleanup; nil while in-progress
isFinalized: Bool        // false during recording; set true on Stop Cleanup before sync attempt
bagsCollected: Int?      // captured in post-cleanup prompt; retained for retry if sync fails
notes: String?           // captured in post-cleanup prompt; retained for retry if sync fails
locationName: String?    // captured in post-cleanup prompt; retained for retry if sync fails
```
`ActiveCleanup` is created on "Start Cleanup" and deleted on successful Firestore sync. If sync fails, the record is retained on-device (`isSynced = false`) so the user's data is not lost and can be retried on next launch (see sync failure and crash recovery notes in Technical Notes).

### `Report`
```
id: String
userId: String
createdAt: Timestamp
latitude: Double
longitude: Double
geohash: String          // geohash of report location, precision 6 (~1.2km cell), for proximity queries
photoURL: String         // Firebase Storage — required; always JPEG (convert HEIC/PNG to JPEG quality 0.8 before upload)
notes: String?
status: "open" | "resolved"
resolvedBy: String?      // userId of whoever marked it resolved
```

### `User`
```
id: String (Firebase UID)
joinedAt: Timestamp
totalDistanceMeters: Double  // denormalized for quick stats
totalCleanups: Int
totalBagsCollected: Int      // denormalized for leaderboards
// displayName, isPublicProfile, currentStreakDays, lastActivityDate deferred to V1.1 (leaderboard work)
```

---

## App Structure

```
LitterPicker/
├── App/
│   └── LitterPickerApp.swift       # App entry point, Firebase config
├── Features/
│   ├── Map/                        # Home screen map view
│   ├── Cleanup/                    # Live tracking + cleanup log
│   ├── Report/                     # Bulky item reporting flow
│   └── Profile/                    # Account + personal stats (private)
├── Models/
│   ├── ActiveCleanup.swift         # SwiftData model — in-progress cleanup (on-device only)
│   ├── Cleanup.swift               # Swift struct mirroring Firestore `cleanups` document
│   ├── Report.swift                # Swift struct mirroring Firestore `reports` document
│   └── User.swift                  # Swift struct mirroring Firestore `users` document
├── Services/
│   ├── LocationService.swift       # CoreLocation, route recording
│   ├── CleanupService.swift        # Local SwiftData write during cleanup; Firestore sync on completion
│   ├── ReportService.swift         # Firestore + Storage for bulky item reports
│   ├── AuthService.swift           # Firebase Auth, anon + Apple
│   ├── UserService.swift           # Create User document on first sign-in; update denormalized stats after cleanup sync
│   └── MapService.swift            # Community map querying — viewport debounce, geohash computation, Firestore queries, overlay coordination, client-side tile cache (tracks which geohash cells have been fetched this session; only queries uncached cells on viewport change; cache discarded on app relaunch)
└── Utilities/
    ├── RouteOpacity.swift          # Time-based fade calculations
    ├── PolylineEncoder.swift       # Google Polyline Encoding/Decoding
    ├── GeohashUtility.swift        # Geohash encode/decode + range query helpers
    ├── Constants.swift             # App-wide constants (e.g. locationDistanceFilter = 5.0)
    └── DistanceFormatter.swift     # Shared MeasurementFormatter wrapper — converts meters to locale-appropriate string (km or miles)
```

---

## Community Map: Time-Based Route Fading

Routes are shown as coloured polylines on the map. Opacity is calculated from age:

| Route age | Opacity |
|---|---|
| 0–1 month | 1.0 (full) |
| 1–6 months | 0.6 |
| 6–12 months | 0.35 |
| 12–24 months | 0.15 |
| 2+ years | 0.05 (barely visible) |

Two map layers:
1. **Own routes** — shown in a distinct green with full opacity; always visible regardless of toggle
2. **Community routes** — anonymous, aggregated, faded by age; rendered in a muted green; hidden/shown by community layer toggle

Both layers render simultaneously by default. Own routes are included in community query results but own-layer rendering takes visual precedence.

---

## Development Phases

### Phase 1 — Project Skeleton
- [ ] Create Xcode project (SwiftUI, iOS 17+)
- [ ] Add Firebase SDK via Swift Package Manager (`firebase-ios-sdk`)
- [ ] Configure `GoogleService-Info.plist` (Firestore, Auth, Storage)
- [ ] Set up Firebase project in console with Firestore rules
- [ ] Skeleton `TabView` or bottom toolbar: Map | Profile

### Phase 2 — Onboarding Flow
- [ ] First launch shows a **single combined screen**: app purpose + location permission rationale + fading map explanation
- [ ] "Get started" button → triggers system location permission dialog → lands on map
- [ ] Map screen shows community routes + prominent "Start your first cleanup" CTA

### Phase 3 — Map Foundation
- [ ] `MapView` using MapKit (`Map` SwiftUI API)
- [ ] Request `WhenInUse` location permission — triggered on onboarding completion (via the "Get started" button), not automatically on app launch
- [ ] On launch, animate the map to the user's current location at neighbourhood zoom level (~1–2 km span)
- [ ] Display user's current location pin
- [ ] Establish overlay layers for cleanups and reports
- [ ] Re-center button: appears as a floating button when the user pans away from their location; tapping snaps the map back to the current GPS position and hides the button

### Phase 4 — Anonymous Auth
- [ ] `AuthService` — sign in anonymously on first launch
- [ ] Persist auth state across app restarts
- [ ] Add "Sign in with Apple" flow (required for App Store)
- [ ] Link anonymous account to Apple ID on sign-in
- [ ] Auth gate: prompt sign-in when user attempts to share a cleanup or submit a report
- [ ] On first sign-in: create `User` document in Firestore via `UserService` (idempotent — use `setData(_:merge: true)` so re-runs are safe)
- [ ] Retroactive sync: after linking anonymous → Apple ID, `AuthService`/`CleanupService` uploads ALL `ActiveCleanup` records with `isFinalized == true && isSynced == false` immediately — this includes records the user previously chose "Save locally", not just ones that failed to sync; on each successful upload: delete the local `ActiveCleanup` from SwiftData and call `UserService` to increment `totalCleanups`, `totalDistanceMeters`, and `totalBagsCollected`

### Phase 5 — Cleanup Logging (MVP)
- [ ] `LocationService` — start/stop continuous GPS recording
- [ ] Enable **Location updates** background mode capability in Xcode (adds `UIBackgroundModes: [location]` to Info.plist)
- [ ] Add `NSLocationWhenInUseUsageDescription` to Info.plist — "Always" permission is not required; background tracking is permitted with WhenInUse once the user has explicitly started a cleanup
- [ ] Set `activityType = .fitness` on `CLLocationManager` so CoreLocation applies appropriate power optimisations
- [ ] Set `distanceFilter = 5` (meters) to balance route accuracy against battery usage
- [ ] On cleanup start: set `allowsBackgroundLocationUpdates = true` and `pausesLocationUpdatesAutomatically = false`
- [ ] On cleanup stop: set `allowsBackgroundLocationUpdates = false` so background tracking ceases immediately
- [ ] iOS displays the blue location indicator in the status bar while a cleanup is active — no additional code needed; this is expected behaviour required by Apple
- [ ] Cleanup recording: accumulate `CLLocationCoordinate2D` array into a SwiftData `ActiveCleanup` model (on-device only)
- [ ] Cleanup screen: full-screen live map with route drawing + elapsed time and distance overlay chip; re-center button behaves the same as the home map (appears when user pans away; tapping snaps back to current GPS position)
- [ ] Visible **Stop** button on cleanup screen; tap opens a confirmation bottom sheet ("End cleanup? / Keep going") — no long-press required
- [ ] On stop: set `isFinalized = true` on `ActiveCleanup`
- [ ] If cleanup duration is under 60 seconds, show an interstitial immediately (before the post-cleanup prompt): "This was a very short cleanup — do you want to discard it?" with Discard and Keep options; if Keep, proceed to post-cleanup prompt; if Discard, delete the local record
- [ ] Post-cleanup prompt: bags collected (Int picker) + notes (text field) + location name (text field, optional)
- [ ] Post-cleanup flow — **authenticated users**: sync `Cleanup` document to Firestore automatically; on success delete local draft
- [ ] Post-cleanup flow — **anonymous users**: summary screen shows two explicit actions: **Share to community** (triggers Sign in with Apple auth gate, then syncs to Firestore) and **Save locally** (saves to SwiftData on-device only, no auth required)
- [ ] On successful sync: call `UserService` to increment `totalCleanups`, `totalDistanceMeters`, and `totalBagsCollected` using `FieldValue.increment(n)` (atomic — no read-modify-write)
- [ ] On sync failure: retain `ActiveCleanup` on-device (`isSynced = false`); show normal success/summary screen — no error shown; retry automatically on next launch
- [ ] On launch: any `ActiveCleanup` with `isFinalized == false` (crashed mid-recording) is silently deleted — no resume prompt
- [ ] Show own cleanup routes as green polylines on the map — anonymous users: rendered from SwiftData `ActiveCleanup` records; authenticated users: rendered from a dedicated Firestore query (`cleanups where userId == uid`) run independently of the community query

### Phase 6 — Community Clean Map
- [ ] Query Firestore for cleanups within map viewport (debounced ~1s after viewport settles)
- [ ] Requery when user pans to a new area — `MapService` computes the centre geohash cell + its 8 neighbours (9 parallel Firestore queries); results merged client-side
- [ ] Cap merged results at **100 most recent** routes before rendering (across all 9 cells)
- [ ] Render anonymous community polylines with `RouteOpacity` fade logic
- [ ] Add overlays sorted oldest-first so MapKit renders the most recent routes on top (last added = highest z-order)
- [ ] **Own routes** (distinct green, full opacity) are always visible and fetched independently of the community query — anonymous: from SwiftData; authenticated: from a dedicated `cleanups where userId == uid` Firestore query not subject to the 100-route cap; community layer toggle hides/shows community routes only; both layers render simultaneously by default

### Phase 7 — Bulky Item Reporting (MVP)
- [ ] Floating Action Button (FAB) on map screen triggers Report flow; uses user's current location — no long-press
- [ ] Add `NSPhotoLibraryUsageDescription` to Info.plist
- [ ] Camera/photo library picker (`PhotosUI`)
- [ ] Upload photo to Firebase Storage
- [ ] Write `Report` document to Firestore with pin location
- [ ] Show bulky item pins on map (distinct marker style)
- [ ] Tap pin to view photo and notes
- [ ] Any authenticated user can mark a report as resolved

### Phase 8 — Profile & Stats
- [ ] Profile screen (authenticated): total distance, total cleanups, bags collected, member since (private — not visible to others)
- [ ] Profile screen (anonymous): show local stats derived from SwiftData `ActiveCleanup` records (total distance, total cleanups, bags collected) + a sign-in prompt explaining the benefits (cross-device history, community sharing)
- [ ] Personal cleanup history list — loads from Firestore (`cleanups where userId == currentUid, orderBy startedAt desc`); survives device change / reinstall for authenticated users; anonymous users have no history list
- [ ] Settings: sign out

### Phase 9 — Polish & App Store Prep
- [ ] App icon, launch screen (green palette)
- [ ] Privacy policy (required for App Store with location + photos) — hosted via GitHub Pages
- [ ] Simple landing/marketing page — hosted via GitHub Pages
- [ ] TestFlight beta
- [ ] App Store submission

---

## V1.1 — Leaderboards, Gamification & Polish

Leaderboards are a core retention and growth driver, not a distant backlog item. Target for V1.1 shortly after App Store launch.

Dependencies before leaderboards can ship:
- Add `displayName: String?` and `isPublicProfile: Bool` to `User` document (additive schema update — safe to apply)
- Denormalized stats on `User` document must be kept up to date on cleanup sync
- Add `currentStreakDays: Int` and `lastActivityDate: Timestamp` to `User` document for streak tracking

Leaderboard ranking dimensions:
- Total distance (all-time)
- Total bags collected (all-time)
- Cleanups this week / this month
- Streak (consecutive days with at least one cleanup)

**Live Activity (ActivityKit)**: elapsed time, distance, and a Stop button on the Lock Screen during an active cleanup. No Dynamic Island UI. Requires `NSSupportsLiveActivities` in Info.plist, an `ActivityAttributes` struct, and a small App Intents target for the Stop button action.

---

## Post-MVP Backlog

- **Events** — organizers create events (location, time, description); others join
- **Streaks & badges** — gamification layer beyond leaderboards
- **Report resolution with photo** — require a 'cleared' photo to close a report
- **Android** — React Native or Flutter once iOS is stable

---

## Technical Notes

- **Firestore security rules**: the Firebase iOS SDK automatically attaches the current user's auth token to every request — no manual token passing needed. Rules to implement:
  - `cleanups`: `allow write: if request.auth != null && request.auth.uid == request.resource.data.userId`; `allow read: if true` (all cleanups synced to Firestore are public by definition)
  - `reports`: `allow write, update: if request.auth != null`; `allow read: if true`
  - `users`: `allow write: if request.auth != null && request.auth.uid == userId`; no public read
- **Distance units**: all distances are stored and computed in meters (SwiftData and Firestore). Display-layer only converts to the device locale using `MeasurementFormatter` with `Measurement<UnitLength>` — metric locales show km, imperial locales (US, UK) show miles. No unit preference is stored per user; it follows the device locale automatically.
- **Local-first cleanups**: active cleanup data lives in SwiftData (`ActiveCleanup`) on-device throughout recording. On "Stop Cleanup", the completed record is written to Firestore (if authenticated) and the local draft is deleted. Unauthenticated users keep cleanups on-device only.
- **Polyline storage**: routes are encoded using the [Google Polyline Encoding Algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithm) before storing in Firestore. Encoded strings are ~75% smaller than raw coordinate arrays, keeping documents well within Firestore's 1MB limit. Decode on read before rendering as a `MKPolyline`. Implement a `PolylineEncoder` utility in Swift (no external dependency needed — the algorithm is simple enough to write in ~50 lines).
- **Geo queries**: Firestore doesn't support native radius queries. Use geohash-based range queries: encode the target location to a geohash prefix, then query `where("geohash", isGreaterThanOrEqualTo: prefix)` + `isLessThanOrEqualTo: prefix + "~"`. Use precision 5 (~5km cell) for cleanup queries and precision 6 (~1.2km cell) for report queries. Add a `GeohashUtility.swift` helper (no external library needed — the algorithm is well-documented and straightforward to implement in Swift).
- **Firebase Storage paths**: report photos stored at `reports/{userId}/{reportId}.jpg`
- **Report photo format**: before upload, convert to JPEG at quality 0.8 regardless of source format (HEIC/PNG/JPEG). `photoURL` is non-optional — a photo is required to submit a report.
- **Stat updates**: `UserService` uses Firestore atomic `FieldValue.increment(n)` for `totalCleanups`, `totalDistanceMeters`, and `totalBagsCollected`. No read-modify-write.
- **Retroactive sync**: when an anonymous user signs in with Apple, `AuthService`/`CleanupService` uploads ALL `ActiveCleanup` records with `isFinalized == true && isSynced == false` immediately — including ones the user previously chose "Save locally". On each successful upload: delete the local record from SwiftData and call `UserService` to increment stats.
- **Crash recovery**: on launch, any `ActiveCleanup` with `isFinalized == false` represents a session that was interrupted before the user tapped Stop. These are silently deleted — no resume prompt.
- **Community map query cap**: after merging results from all 9 geohash cell queries, take the 100 most recent routes before rendering. `MapService` maintains a client-side tile cache tracking which geohash cells have been fetched this session; on viewport change, only uncached cells are queried. Cache is discarded on app relaunch.
- **Background location**: the background location entitlement will be requested. The use case (user-initiated outdoor activity tracking) is a legitimate, well-documented scenario that Apple regularly approves. Prepare a strong justification string for the privacy manifest.
- **App name**: "Litter Picker" is a working title. Finalise before App Store submission.
- **Web presence**: privacy policy and landing page are required for MVP App Store submission. Host via GitHub Pages — a `docs/` folder in the repo (or a dedicated `gh-pages` branch) serves the static HTML at `https://<username>.github.io/<repo>/`.
