import SwiftUI
import SwiftData

struct PostCleanupView: View {
    let cleanup: ActiveCleanup
    let onDone: () -> Void

    @Environment(AuthService.self) private var authService
    @Environment(CleanupService.self) private var cleanupService
    @Environment(UserService.self) private var userService
    @Environment(\.modelContext) private var modelContext

    @State private var bagsCollected: Int = 0
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var isSubmitting = false
    @State private var showAuthSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("How did it go?") {
                    Stepper("Bags collected: \(bagsCollected)", value: $bagsCollected, in: 0...99)
                    TextField("Location name (optional)", text: $locationName)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if authService.isSignedIn {
                        // Authenticated: auto-sync
                        Button {
                            Task { await submitAuthenticated() }
                        } label: {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Save & share to community")
                            }
                        }
                        .disabled(isSubmitting)
                    } else {
                        // Anonymous: two options
                        Button {
                            showAuthSheet = true
                        } label: {
                            Label("Share to community", systemImage: "globe")
                        }

                        Button {
                            saveLocally()
                        } label: {
                            Label("Save locally", systemImage: "internaldrive")
                        }
                    }
                }
            }
            .navigationTitle("Cleanup complete!")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAuthSheet) {
            SignInPromptView(reason: "Sign in to share your cleanup with the community.") {
                Task { await submitAuthenticated() }
            }
        }
        .task {
            // If already authenticated, attempt auto-sync
            if authService.isSignedIn, let uid = authService.uid {
                applyFormToCleanup()
                await cleanupService.syncToFirestore(
                    record: cleanup,
                    uid: uid,
                    modelContext: modelContext,
                    userService: userService
                )
                onDone()
            }
        }
    }

    private func applyFormToCleanup() {
        cleanup.bagsCollected = bagsCollected > 0 ? bagsCollected : nil
        cleanup.notes = notes.isEmpty ? nil : notes
        cleanup.locationName = locationName.isEmpty ? nil : locationName
        try? modelContext.save()
    }

    private func submitAuthenticated() async {
        guard let uid = authService.uid else { return }
        isSubmitting = true
        applyFormToCleanup()
        await cleanupService.syncToFirestore(
            record: cleanup,
            uid: uid,
            modelContext: modelContext,
            userService: userService
        )
        isSubmitting = false
        onDone()
    }

    private func saveLocally() {
        applyFormToCleanup()
        onDone()
    }
}
