import Foundation
import SwiftData
import CoreLocation

@Model
final class ActiveCleanup {
    var id: UUID
    var startedAt: Date
    /// Serialised [CLLocationCoordinate2D] as flat [Double] (lat, lon pairs)
    var coordinatesData: Data
    var distanceMeters: Double
    var isSynced: Bool
    var endedAt: Date?
    var isFinalized: Bool
    var bagsCollected: Int?
    var notes: String?
    var locationName: String?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        coordinatesData: Data = Data(),
        distanceMeters: Double = 0,
        isSynced: Bool = false,
        endedAt: Date? = nil,
        isFinalized: Bool = false,
        bagsCollected: Int? = nil,
        notes: String? = nil,
        locationName: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.coordinatesData = coordinatesData
        self.distanceMeters = distanceMeters
        self.isSynced = isSynced
        self.endedAt = endedAt
        self.isFinalized = isFinalized
        self.bagsCollected = bagsCollected
        self.notes = notes
        self.locationName = locationName
    }

    var coordinates: [CLLocationCoordinate2D] {
        get {
            let doubles = coordinatesData.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Double.self))
            }
            var result: [CLLocationCoordinate2D] = []
            var i = 0
            while i + 1 < doubles.count {
                result.append(CLLocationCoordinate2D(latitude: doubles[i], longitude: doubles[i + 1]))
                i += 2
            }
            return result
        }
        set {
            var doubles: [Double] = []
            for coord in newValue {
                doubles.append(coord.latitude)
                doubles.append(coord.longitude)
            }
            coordinatesData = doubles.withUnsafeBytes { Data($0) }
        }
    }

    var durationSeconds: TimeInterval? {
        guard let ended = endedAt else { return nil }
        return ended.timeIntervalSince(startedAt)
    }
}
