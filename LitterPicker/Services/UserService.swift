import Foundation
import FirebaseFirestore

@Observable
final class UserService {
    private let db = Firestore.firestore()

    func createUserIfNeeded(uid: String) async throws {
        let ref = db.collection("users").document(uid)
        let user = AppUser(
            id: uid,
            joinedAt: Date(),
            totalDistanceMeters: 0,
            totalCleanups: 0,
            totalBagsCollected: 0
        )
        let data: [String: Any] = [
            "id": user.id,
            "joinedAt": Timestamp(date: user.joinedAt),
            "totalDistanceMeters": user.totalDistanceMeters,
            "totalCleanups": user.totalCleanups,
            "totalBagsCollected": user.totalBagsCollected
        ]
        try await ref.setData(data, merge: true)
    }

    func incrementStats(uid: String, distanceMeters: Double, bagsCollected: Int?) async throws {
        let ref = db.collection("users").document(uid)
        var updates: [String: Any] = [
            "totalDistanceMeters": FieldValue.increment(distanceMeters),
            "totalCleanups": FieldValue.increment(Int64(1))
        ]
        if let bags = bagsCollected {
            updates["totalBagsCollected"] = FieldValue.increment(Int64(bags))
        }
        try await ref.updateData(updates)
    }

    func fetchUser(uid: String) async throws -> AppUser? {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return AppUser(
            id: uid,
            joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date(),
            totalDistanceMeters: data["totalDistanceMeters"] as? Double ?? 0,
            totalCleanups: data["totalCleanups"] as? Int ?? 0,
            totalBagsCollected: data["totalBagsCollected"] as? Int ?? 0
        )
    }
}
