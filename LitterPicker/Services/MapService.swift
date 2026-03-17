import Foundation
import FirebaseFirestore
import CoreLocation

@Observable
final class MapService {
    private let db = Firestore.firestore()

    private(set) var communityCleanups: [Cleanup] = []
    private(set) var isLoading: Bool = false

    /// Client-side tile cache: geohash cells fetched this session
    private var fetchedCells: Set<String> = []
    private var cachedCleanups: [Cleanup] = []

    // MARK: - Fetch

    func fetchCommunityCleanups(latitude: Double, longitude: Double) async {
        let allCells = GeohashUtility.nineCell(
            latitude: latitude,
            longitude: longitude,
            precision: Constants.geohashPrecisionCleanup
        )
        let newCells = allCells.filter { !fetchedCells.contains($0) }
        guard !newCells.isEmpty else {
            communityCleanups = Array(cachedCleanups
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(Constants.communityMapCap))
            return
        }

        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: [Cleanup].self) { group in
            for cell in newCells {
                group.addTask { [weak self] in
                    await self?.queryCell(cell) ?? []
                }
            }
            for await results in group {
                cachedCleanups.append(contentsOf: results)
            }
        }

        for cell in newCells { fetchedCells.insert(cell) }

        // De-duplicate by id and cap
        var seen = Set<String>()
        let deduped = cachedCleanups.filter { seen.insert($0.id).inserted }
        cachedCleanups = deduped

        communityCleanups = Array(
            cachedCleanups
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(Constants.communityMapCap)
        )
    }

    func resetCache() {
        fetchedCells = []
        cachedCleanups = []
        communityCleanups = []
    }

    // MARK: - Private

    private func queryCell(_ geohash: String) async -> [Cleanup] {
        let (lower, upper) = GeohashUtility.range(for: geohash)
        do {
            let snapshot = try await db.collection("cleanups")
                .whereField("startGeohash", isGreaterThanOrEqualTo: lower)
                .whereField("startGeohash", isLessThanOrEqualTo: upper)
                .limit(to: 50)
                .getDocuments()
            return snapshot.documents.compactMap { parseCleanup($0.data()) }
        } catch {
            return []
        }
    }

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
