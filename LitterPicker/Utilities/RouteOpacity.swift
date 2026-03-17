import Foundation

enum RouteOpacity {
    static func opacity(for date: Date) -> Double {
        let ageSeconds = Date().timeIntervalSince(date)
        let ageMonths = ageSeconds / (30.0 * 24.0 * 3600.0)
        switch ageMonths {
        case ..<1:    return 1.0
        case ..<6:    return 0.6
        case ..<12:   return 0.35
        case ..<24:   return 0.15
        default:      return 0.05
        }
    }
}
