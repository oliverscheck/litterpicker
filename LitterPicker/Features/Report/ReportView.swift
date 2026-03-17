import SwiftUI
import PhotosUI
import CoreLocation

struct ReportView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ReportService.self) private var reportService
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var showAuthGate = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo (required)") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select photo", systemImage: "camera.fill")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task {
                            guard let item else { return }
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                // Convert to JPEG quality 0.8
                                if let uiImage = UIImage(data: data) {
                                    photoData = uiImage.jpegData(compressionQuality: 0.8)
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report bulky item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        if authService.isSignedIn {
                            Task { await submit() }
                        } else {
                            showAuthGate = true
                        }
                    }
                    .disabled(photoData == nil || isSubmitting)
                }
            }
        }
        .sheet(isPresented: $showAuthGate) {
            SignInPromptView(reason: "Sign in to submit a bulky item report.") {
                Task { await submit() }
            }
        }
    }

    private func submit() async {
        guard let data = photoData,
              let uid = authService.uid,
              let location = locationService.currentLocation?.coordinate else { return }
        isSubmitting = true
        do {
            try await reportService.submitReport(
                userId: uid,
                location: location,
                photoData: data,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
