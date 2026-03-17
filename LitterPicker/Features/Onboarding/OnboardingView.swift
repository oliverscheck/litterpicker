import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(LocationService.self) private var locationService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("Litter Picker")
                    .font(.largeTitle.bold())

                Text("Record your cleanups, see what others have cleaned, and make your neighbourhood greener.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                FeatureRow(icon: "map.fill", color: .green,
                           title: "Track your route",
                           description: "Live GPS tracking as you clean")
                FeatureRow(icon: "person.2.fill", color: .blue,
                           title: "Community map",
                           description: "Routes fade over time — see where to go next")
                FeatureRow(icon: "trash.fill", color: .orange,
                           title: "Report bulky items",
                           description: "Pin large items so others can help")
            }
            .padding(.horizontal)

            Spacer()

            Button {
                locationService.requestWhenInUseAuthorization()
                hasCompletedOnboarding = true
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
