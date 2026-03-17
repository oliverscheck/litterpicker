import Foundation
import SwiftData
import FirebaseFirestore
import CoreLocation

@Observable
final class CleanupService {
    private let db = Firestore.firestore()

    // MARK: - Launch recovery

    /// Deletes unfinalized (crashed) records; retries finalized-but-unsynced records for authenticated users.
    func performLaunchRecovery(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<ActiveCleanup>()
        guard let all = try? modelContext.fetch(descriptor) else { return }

        for record in all {
            if !record.isFinalized {
                // Crashed mid-recording — silently delete
                modelContext.delete(record)
            }
        }
        try? modelContext.save()
    }

    /// Retries all unsynced finalized records for an authenticated user (called after sign-in and on launch).
    func retryPendingUploads(
        modelContext: ModelContext,
        uid: String,
        userService: UserService
    ) async {
        let descriptor = FetchDescriptor<ActiveCleanup>(
            predicate: #Predicate { $0.isFinalized == true && $0.isSynced == false }
        )
        guard let pending = try? modelContext.fetch(descriptor) else { return }
        for record in pending {
            await syncToFirestore(record: record, uid: uid, modelContext: modelContext, userService: userService)
        }
    }

    // MARK: - Sync

    func syncToFirestore(
        record: ActiveCleanup,
        uid: String,
        modelContext: ModelContext,
        userService: UserService
    ) async {
        guard let endedAt = record.endedAt else { return }
        let coords = record.coordinates
        guard !coords.isEmpty else { return }

        let startGeohash = GeohashUtility.encode(
            latitude: coords[0].latitude,
            longitude: coords[0].longitude,
            precision: Constants.geohashPrecisionCleanup
        )

        let docId = record.id.uuidString
        let data: [String: Any] = [
            "id": docId,
            "userId": uid,
            "startedAt": Timestamp(date: record.startedAt),
            "endedAt": Timestamp(date: endedAt),
            "durationSeconds": Int(record.durationSeconds ?? 0),
            "distanceMeters": record.distanceMeters,
            "encodedPolyline": PolylineEncoder.encode(coords),
            "startGeohash": startGeohash,
            "bagsCollected": record.bagsCollected as Any,
            "notes": record.notes as Any,
            "locationName": record.locationName as Any
        ]

        do {
            try await db.collection("cleanups").document(docId).setData(data)
            record.isSynced = true
            try? modelContext.save()
            // Increment user stats
            try? await userService.incrementStats(
                uid: uid,
                distanceMeters: record.distanceMeters,
                bagsCollected: record.bagsCollected
            )
            // Delete local draft
            modelContext.delete(record)
            try? modelContext.save()
        } catch {
            // Retain on-device for retry; no error shown to user
            record.isSynced = false
            try? modelContext.save()
        }
    }

    // MARK: - Own route query (authenticated users)

    func fetchOwnCleanups(uid: String) async -> [Cleanup] {
        do {
            let snapshot = try await db.collection("cleanups")
                .whereField("userId", isEqualTo: uid)
                .order(by: "startedAt", descending: true)
                .limit(to: 200)
                .getDocuments()
            return snapshot.documents.compactMap { parseCleanup($0.data()) }
        } catch {
            return []
        }
    }

    // MARK: - Helpers

    private func parseCleanup(_ data: [String: Any]) -> Cleanup? {
        guard
            let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let startedAt = (data["startedAt"] as? Timestamp)?.dateValue(),
            let endedAt = (data["endedAt"] as? Timestamp)?.dateValue(),
            let duration = data["durationSeconds"] as? Int,
            let distance = data["distanceMeters"] as? Double,
            let polyline = data["encodedPolyline"] as? String,
            let geohash = data["startGeohash"] as? String
        else { return nil }

        return Cleanup(
            id: id,
            userId: userId,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: duration,
            distanceMeters: distance,
            encodedPolyline: polyline,
            startGeohash: geohash,
            bagsCollected: data["bagsCollected"] as? Int,
            notes: data["notes"] as? String,
            locationName: data["locationName"] as? String
        )
    }
}
