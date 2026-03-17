import SwiftUI
import MapKit
import SwiftData

struct CleanupView: View {
    @Environment(AuthService.self) private var authService
    @Environment(LocationService.self) private var locationService
    @Environment(CleanupService.self) private var cleanupService
    @Environment(UserService.self) private var userService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var activeCleanup: ActiveCleanup?
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var userHasPanned = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showStopConfirmation = false
    @State private var showShortCleanupAlert = false
    @State private var showPostCleanup = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let cleanup = activeCleanup {
                    let coords = cleanup.coordinates
                    if !coords.isEmpty {
                        MapPolyline(coordinates: coords)
                            .stroke(.green, lineWidth: 4)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                if let userLoc = locationService.currentLocation?.coordinate {
                    let dist = CLLocation(latitude: context.camera.centerCoordinate.latitude,
                                         longitude: context.camera.centerCoordinate.longitude)
                        .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                    userHasPanned = dist > 50
                }
            }
            .ignoresSafeArea()

            VStack {
                // Stats chip
                HStack(spacing: 20) {
                    Label(formatDuration(elapsedTime), systemImage: "timer")
                    Divider().frame(height: 20)
                    Label(DistanceFormatter.string(fromMeters: activeCleanup?.distanceMeters ?? 0),
                          systemImage: "figure.walk")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(.top, 60)

                Spacer()

                HStack {
                    Spacer()
                    if userHasPanned {
                        Button {
                            cameraPosition = .userLocation(fallback: .automatic)
                            userHasPanned = false
                        } label: {
                            Image(systemName: "location.fill")
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 100)
                    }
                }

                // Stop button
                Button {
                    showStopConfirmation = true
                } label: {
                    Text("Stop")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog("End cleanup?", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("End cleanup", role: .destructive) { stopCleanup() }
            Button("Keep going", role: .cancel) {}
        }
        .alert("Very short cleanup", isPresented: $showShortCleanupAlert) {
            Button("Discard", role: .destructive) { discardCleanup() }
            Button("Keep") { showPostCleanup = true }
        } message: {
            Text("This cleanup was under a minute. Discard it or keep it?")
        }
        .fullScreenCover(isPresented: $showPostCleanup) {
            if let cleanup = activeCleanup {
                PostCleanupView(cleanup: cleanup, onDone: { dismiss() })
            }
        }
        .task {
            startCleanup()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startCleanup() {
        let cleanup = ActiveCleanup()
        modelContext.insert(cleanup)
        try? modelContext.save()
        activeCleanup = cleanup

        locationService.startRecording()
        locationService.onLocationUpdate = { [weak cleanup] _ in
            guard let cleanup = cleanup else { return }
            cleanup.coordinates = locationService.routeCoordinates
            cleanup.distanceMeters = locationService.distanceMeters
            try? modelContext.save()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(activeCleanup?.startedAt ?? Date())
        }
    }

    private func stopCleanup() {
        timer?.invalidate()
        locationService.stopRecording()

        guard let cleanup = activeCleanup else { return }
        cleanup.endedAt = Date()
        cleanup.isFinalized = true
        cleanup.coordinates = locationService.routeCoordinates
        cleanup.distanceMeters = locationService.distanceMeters
        try? modelContext.save()

        if let duration = cleanup.durationSeconds, duration < Constants.shortCleanupThreshold {
            showShortCleanupAlert = true
        } else {
            showPostCleanup = true
        }
    }

    private func discardCleanup() {
        if let cleanup = activeCleanup {
            modelContext.delete(cleanup)
            try? modelContext.save()
        }
        dismiss()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
