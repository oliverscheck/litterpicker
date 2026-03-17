import SwiftUI

struct SignInPromptView: View {
    let reason: String
    let onSuccess: () -> Void

    @Environment(AuthService.self) private var authService
    @Environment(UserService.self) private var userService
    @Environment(CleanupService.self) private var cleanupService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text(reason)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if isSigningIn {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("Sign in with Apple", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() async {
        isSigningIn = true
        do {
            try await authService.startSignInWithApple()
            if let uid = authService.uid {
                try? await userService.createUserIfNeeded(uid: uid)
                // Retroactive sync: upload ALL unsynced finalized records
                await cleanupService.retryPendingUploads(
                    modelContext: modelContext,
                    uid: uid,
                    userService: userService
                )
            }
            dismiss()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }
}
