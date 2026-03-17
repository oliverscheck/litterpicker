import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @Environment(CleanupService.self) private var cleanupService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                MainTabView()
            }
        }
        .task {
            await cleanupService.performLaunchRecovery(modelContext: modelContext)
            if authService.currentUser == nil {
                try? await authService.signInAnonymously()
            }
        }
    }
}
