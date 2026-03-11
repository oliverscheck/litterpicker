# Litter Picker — Architecture & Development Plan

## Vision

An iOS app for coordinating and logging litter picking activity. Users can record solo cleanup sessions with live GPS tracking, report hard-to-remove objects on the map, and see a community clean map where routes fade over time to reflect how recently an area was cleaned.

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

---

## Data Models

### `Session`
```
id: String
userId: String (anonymous or real)
startedAt: Timestamp
endedAt: Timestamp
durationSeconds: Int
distanceMeters: Double
routeCoordinates: [[latitude, longitude]]  // GeoJSON-style array
isPublic: Bool  // user can opt-out of community map
```

### `Report`
```
id: String
userId: String
createdAt: Timestamp
latitude: Double
longitude: Double
photoURL: String  // Firebase Storage
notes: String?
status: "open" | "resolved"
```

### `User`
```
id: String (Firebase UID)
displayName: String?
joinedAt: Timestamp
totalDistanceMeters: Double  // denormalized for quick stats
totalSessions: Int
```

---

## App Structure

```
LitterPicker/
├── App/
│   └── LitterPickerApp.swift       # App entry point, Firebase config
├── Features/
│   ├── Map/                        # Home screen map view
│   ├── Session/                    # Live tracking + session log
│   ├── Report/                     # Object reporting flow
│   └── Profile/                    # Account + personal stats
├── Models/                         # Swift structs mirroring Firestore docs
├── Services/
│   ├── LocationService.swift       # CoreLocation, route recording
│   ├── SessionService.swift        # Firestore CRUD for sessions
│   ├── ReportService.swift         # Firestore + Storage for reports
│   └── AuthService.swift           # Firebase Auth, anon + Apple
└── Utilities/
    └── RouteOpacity.swift          # Time-based fade calculations
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
1. **Own routes** — shown in a distinct colour with full opacity
2. **Community routes** — anonymous, aggregated, faded by age

---

## Development Phases

### Phase 1 — Project Skeleton
- [ ] Create Xcode project (SwiftUI, iOS 17+)
- [ ] Add Firebase SDK via Swift Package Manager (`firebase-ios-sdk`)
- [ ] Configure `GoogleService-Info.plist` (Firestore, Auth, Storage)
- [ ] Set up Firebase project in console with Firestore rules
- [ ] Skeleton `TabView` or bottom toolbar: Map | Profile

### Phase 2 — Map Foundation
- [ ] `MapView` using MapKit (`Map` SwiftUI API)
- [ ] Request `WhenInUse` location permission on launch
- [ ] Display user's current location pin
- [ ] Establish overlay layers for sessions and reports

### Phase 3 — Anonymous Auth
- [ ] `AuthService` — sign in anonymously on first launch
- [ ] Persist auth state across app restarts
- [ ] Add "Sign in with Apple" flow (required for App Store)
- [ ] Link anonymous account to Apple ID on sign-in

### Phase 4 — Session Logging (MVP)
- [ ] `LocationService` — start/stop continuous GPS recording
- [ ] Background location mode entitlement
- [ ] Session recording: accumulate `CLLocationCoordinate2D` array
- [ ] "Start Session" / "Stop Session" UI with live elapsed time and distance
- [ ] On stop: write `Session` document to Firestore
- [ ] Show own session routes as polylines on the map

### Phase 5 — Community Clean Map
- [ ] Query Firestore for public sessions within map viewport
- [ ] Render anonymous community polylines with `RouteOpacity` fade logic
- [ ] Toggle: own routes vs. community routes

### Phase 6 — Object Reporting (MVP)
- [ ] "Report" button on map (long-press or FAB)
- [ ] Camera/photo library picker (`PhotosUI`)
- [ ] Upload photo to Firebase Storage
- [ ] Write `Report` document to Firestore with pin location
- [ ] Show report pins on map (distinct marker style)
- [ ] Tap pin to view photo and notes

### Phase 7 — Profile & Stats
- [ ] Profile screen: total distance, total sessions, member since
- [ ] Personal session history list
- [ ] Settings: toggle public/private routes, sign out

### Phase 8 — Polish & App Store Prep
- [ ] App icon, launch screen
- [ ] Onboarding flow (location permission rationale)
- [ ] Privacy policy (required for App Store with location + photos)
- [ ] TestFlight beta
- [ ] App Store submission

---

## Post-MVP Backlog

- **Events** — organizers create events (location, time, description); others join
- **Leaderboards** — distance-based rankings by week/month/all-time
- **Streaks & badges** — gamification layer
- **Report resolution** — mark reported items as cleared
- **Android** — React Native or Flutter once iOS is stable

---

## Technical Notes

- **Firestore security rules**: lock writes to authenticated users; reads for community routes scoped to public sessions only
- **Battery**: CoreLocation `distanceFilter` of ~5m balances accuracy vs. battery during sessions
- **Polyline storage**: store coordinates as a Firestore array; for long sessions consider GeoJSON in Firebase Storage instead to avoid document size limits (1MB Firestore max)
- **Map viewport queries**: Firestore doesn't natively support geo queries — use the `GeoFirestore` pattern (geohash field) or query a bounding box on lat/lng fields
