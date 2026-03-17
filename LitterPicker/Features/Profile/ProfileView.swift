import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(UserService.self) private var userService
    @Environment(CleanupService.self) private var cleanupService
    @Environment(\.modelContext) private var modelContext

    @State private var appUser: AppUser?
    @State private var showSignIn = false
    @Query private var localCleanups: [ActiveCleanup]

    var body: some View {
        NavigationStack {
            List {
                if authService.isSignedIn {
                    authenticatedContent
                } else {
                    anonymousContent
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if authService.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out", role: .destructive) {
                            try? authService.signOut()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInPromptView(reason: "Sign in to sync your cleanups across devices and share with the community.") {}
        }
        .task {
            if let uid = authService.uid, authService.isSignedIn {
                appUser = try? await userService.fetchUser(uid: uid)
            }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if let user = appUser {
            Section("Your stats") {
                StatRow(label: "Total cleanups", value: "\(user.totalCleanups)")
                StatRow(label: "Total distance", value: DistanceFormatter.string(fromMeters: user.totalDistanceMeters))
                StatRow(label: "Bags collected", value: "\(user.totalBagsCollected)")
                StatRow(label: "Member since", value: user.joinedAt.formatted(date: .abbreviated, time: .omitted))
            }
        } else {
            Section { ProgressView() }
        }
    }

    @ViewBuilder
    private var anonymousContent: some View {
        let finalized = localCleanups.filter { $0.isFinalized }
        let totalDistance = finalized.reduce(0.0) { $0 + $1.distanceMeters }
        let totalBags = finalized.compactMap { $0.bagsCollected }.reduce(0, +)

        Section("Your local stats") {
            StatRow(label: "Cleanups recorded", value: "\(finalized.count)")
            StatRow(label: "Total distance", value: DistanceFormatter.string(fromMeters: totalDistance))
            StatRow(label: "Bags collected", value: "\(totalBags)")
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in to unlock")
                    .font(.headline)
                Text("• Sync your cleanups across devices\n• Share routes to the community map\n• Submit bulky item reports\n• See your all-time history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Sign in with Apple") {
                    showSignIn = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
