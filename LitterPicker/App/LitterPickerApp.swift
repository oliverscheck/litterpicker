import SwiftUI
import SwiftData
import FirebaseCore

@main
struct LitterPickerApp: App {
    @State private var authService = AuthService()
    @State private var locationService = LocationService()
    @State private var cleanupService = CleanupService()
    @State private var mapService = MapService()
    @State private var reportService = ReportService()
    @State private var userService = UserService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(locationService)
                .environment(cleanupService)
                .environment(mapService)
                .environment(reportService)
                .environment(userService)
        }
        .modelContainer(for: ActiveCleanup.self)
    }
}
