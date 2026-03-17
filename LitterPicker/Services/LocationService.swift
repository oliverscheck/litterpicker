import Foundation
import CoreLocation
import Combine

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isRecording: Bool = false

    /// Accumulated route coordinates during an active cleanup
    private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    private(set) var distanceMeters: Double = 0
    private var lastRecordedLocation: CLLocation?

    /// Callback fired on each new location during recording (for live SwiftData update)
    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = Constants.locationDistanceFilter
        manager.activityType = .fitness
    }

    // MARK: - Permission

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Recording

    func startRecording() {
        routeCoordinates = []
        distanceMeters = 0
        lastRecordedLocation = nil
        isRecording = true
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func stopRecording() {
        isRecording = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
    }

    func resetRoute() {
        routeCoordinates = []
        distanceMeters = 0
        lastRecordedLocation = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        guard isRecording else { return }

        if let last = lastRecordedLocation {
            distanceMeters += location.distance(from: last)
        }
        lastRecordedLocation = location
        routeCoordinates.append(location.coordinate)
        onLocationUpdate?(location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
