import Foundation

enum DistanceFormatter {
    private static let formatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .naturalScale
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    static func string(fromMeters meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}
