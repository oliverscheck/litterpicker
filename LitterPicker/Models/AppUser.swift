import Foundation

struct AppUser: Identifiable, Codable {
    let id: String
    let joinedAt: Date
    var totalDistanceMeters: Double
    var totalCleanups: Int
    var totalBagsCollected: Int
}
