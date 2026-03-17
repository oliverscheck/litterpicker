import Foundation

struct Report: Identifiable, Codable {
    let id: String
    let userId: String
    let createdAt: Date
    let latitude: Double
    let longitude: Double
    let geohash: String
    let photoURL: String
    let notes: String?
    var status: ReportStatus
    var resolvedBy: String?

    enum ReportStatus: String, Codable {
        case open, resolved
    }
}
