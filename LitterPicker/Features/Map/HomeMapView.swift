import SwiftUI
import MapKit
import SwiftData

struct HomeMapView: View {
    @Environment(AuthService.self) private var authService
    @Environment(LocationService.self) private var locationService
    @Environment(MapService.self) private var mapService
    @Environment(CleanupService.self) private var cleanupService
    @Environment(UserService.self) private var userService
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = HomeMapViewModel()

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var userHasPanned = false
    @State private var showCleanupView = false
    @State private var showReportView = false
    @State private var showCommunityRoutes = true
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var debounceTask: Task<Void, Never>?

    @Query private var localCleanups: [ActiveCleanup]

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                // Community routes
                if showCommunityRoutes {
                    ForEach(mapService.communityCleanups) { cleanup in
                        let coords = PolylineEncoder.decode(cleanup.encodedPolyline)
                        if !coords.isEmpty {
                            MapPolyline(coordinates: coords)
                                .stroke(
                                    Color.green.opacity(RouteOpacity.opacity(for: cleanup.startedAt) * 0.6),
                                    lineWidth: 3
                                )
                        }
                    }
                }

                // Own routes — authenticated: fetched from Firestore
                ForEach(viewModel.ownCleanups) { cleanup in
                    let coords = PolylineEncoder.decode(cleanup.encodedPolyline)
                    if !coords.isEmpty {
                        MapPolyline(coordinates: coords)
                            .stroke(.green, lineWidth: 4)
                    }
                }

                // Own local (SwiftData) cleanups for anonymous users
                if authService.isAnonymous {
                    ForEach(localCleanups.filter { $0.isFinalized }) { cleanup in
                        let coords = cleanup.coordinates
                        if !coords.isEmpty {
                            MapPolyline(coordinates: coords)
                                .stroke(.green, lineWidth: 4)
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                let center = context.camera.centerCoordinate
                if let userLoc = locationService.currentLocation?.coordinate {
                    let dist = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                    userHasPanned = dist > 50
                }
                mapCenter = center
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .seconds(Constants.mapDebounceInterval))
                    guard !Task.isCancelled, let center = mapCenter else { return }
                    await mapService.fetchCommunityCleanups(latitude: center.latitude, longitude: center.longitude)
                }
            }
            .ignoresSafeArea()

            // Overlay controls
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // Community layer toggle
                        Button {
                            showCommunityRoutes.toggle()
                        } label: {
                            Image(systemName: showCommunityRoutes ? "eye.fill" : "eye.slash.fill")
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                        }

                        // Re-center button
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
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 60)

                Spacer()

                // Bottom action buttons
                HStack(spacing: 16) {
                    // Report FAB
                    Button {
                        showReportView = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .padding(16)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    Spacer()

                    // Start cleanup CTA
                    Button {
                        showCleanupView = true
                    } label: {
                        Label("Start cleanup", systemImage: "figure.walk")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showCleanupView) {
            CleanupView()
        }
        .sheet(isPresented: $showReportView) {
            ReportView()
        }
        .task {
            if let loc = locationService.currentLocation?.coordinate {
                await mapService.fetchCommunityCleanups(latitude: loc.latitude, longitude: loc.longitude)
            }
            // Fetch authenticated user's own routes
            if let uid = authService.uid, !authService.isAnonymous {
                viewModel.ownCleanups = await cleanupService.fetchOwnCleanups(uid: uid)
            }
        }
    }
}

@MainActor
final class HomeMapViewModel: ObservableObject {
    var ownCleanups: [Cleanup] = []
}
