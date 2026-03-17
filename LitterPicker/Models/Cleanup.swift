import Foundation
import CoreLocation

struct Cleanup: Identifiable, Codable {
    let id: String
    let userId: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let distanceMeters: Double
    let encodedPolyline: String
    let startGeohash: String
    let bagsCollected: Int?
    let notes: String?
    let locationName: String?

    var startLocation: CLLocationCoordinate2D? {
        GeohashUtility.decode(startGeohash).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}
