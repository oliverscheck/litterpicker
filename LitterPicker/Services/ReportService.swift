import Foundation
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

@Observable
final class ReportService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func submitReport(
        userId: String,
        location: CLLocationCoordinate2D,
        photoData: Data,
        notes: String?
    ) async throws {
        let reportId = UUID().uuidString
        let path = "reports/\(userId)/\(reportId).jpg"
        let ref = storage.reference(withPath: path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(photoData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()

        let geohash = GeohashUtility.encode(
            latitude: location.latitude,
            longitude: location.longitude,
            precision: Constants.geohashPrecisionReport
        )

        let data: [String: Any] = [
            "id": reportId,
            "userId": userId,
            "createdAt": Timestamp(date: Date()),
            "latitude": location.latitude,
            "longitude": location.longitude,
            "geohash": geohash,
            "photoURL": downloadURL.absoluteString,
            "notes": notes as Any,
            "status": "open"
        ]
        try await db.collection("reports").document(reportId).setData(data)
    }

    func fetchReports(latitude: Double, longitude: Double) async -> [Report] {
        let cells = GeohashUtility.nineCell(
            latitude: latitude,
            longitude: longitude,
            precision: Constants.geohashPrecisionReport
        )
        var results: [Report] = []
        for cell in cells {
            let (lower, upper) = GeohashUtility.range(for: cell)
            if let snap = try? await db.collection("reports")
                .whereField("geohash", isGreaterThanOrEqualTo: lower)
                .whereField("geohash", isLessThanOrEqualTo: upper)
                .getDocuments() {
                results += snap.documents.compactMap { parseReport($0.data()) }
            }
        }
        return results
    }

    func resolveReport(reportId: String, resolvedBy: String) async throws {
        try await db.collection("reports").document(reportId).updateData([
            "status": "resolved",
            "resolvedBy": resolvedBy
        ])
    }

    private func parseReport(_ data: [String: Any]) -> Report? {
        guard
            let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let lat = data["latitude"] as? Double,
            let lon = data["longitude"] as? Double,
            let geohash = data["geohash"] as? String,
            let photoURL = data["photoURL"] as? String,
            let statusStr = data["status"] as? String,
            let status = Report.ReportStatus(rawValue: statusStr)
        else { return nil }

        return Report(
            id: id,
            userId: userId,
            createdAt: createdAt,
            latitude: lat,
            longitude: lon,
            geohash: geohash,
            photoURL: photoURL,
            notes: data["notes"] as? String,
            status: status,
            resolvedBy: data["resolvedBy"] as? String
        )
    }
}
