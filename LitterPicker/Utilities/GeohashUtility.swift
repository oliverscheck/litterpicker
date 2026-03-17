import Foundation
import CoreLocation

enum GeohashUtility {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let base32Map: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (i, c) in base32.enumerated() { map[c] = i }
        return map
    }()

    // MARK: - Encode

    static func encode(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        var minLat = -90.0, maxLat = 90.0
        var minLon = -180.0, maxLon = 180.0
        var result = ""
        var bits = 0
        var hash = 0
        var isLon = true

        while result.count < precision {
            if isLon {
                let mid = (minLon + maxLon) / 2
                if longitude >= mid {
                    hash = (hash << 1) | 1
                    minLon = mid
                } else {
                    hash = hash << 1
                    maxLon = mid
                }
            } else {
                let mid = (minLat + maxLat) / 2
                if latitude >= mid {
                    hash = (hash << 1) | 1
                    minLat = mid
                } else {
                    hash = hash << 1
                    maxLat = mid
                }
            }
            isLon.toggle()
            bits += 1
            if bits == 5 {
                result.append(base32[hash])
                hash = 0
                bits = 0
            }
        }
        return result
    }

    // MARK: - Decode

    static func decode(_ geohash: String) -> (latitude: Double, longitude: Double)? {
        guard !geohash.isEmpty else { return nil }
        var minLat = -90.0, maxLat = 90.0
        var minLon = -180.0, maxLon = 180.0
        var isLon = true

        for char in geohash {
            guard let value = base32Map[char] else { return nil }
            for i in stride(from: 4, through: 0, by: -1) {
                let bit = (value >> i) & 1
                if isLon {
                    let mid = (minLon + maxLon) / 2
                    if bit == 1 { minLon = mid } else { maxLon = mid }
                } else {
                    let mid = (minLat + maxLat) / 2
                    if bit == 1 { minLat = mid } else { maxLat = mid }
                }
                isLon.toggle()
            }
        }
        return ((minLat + maxLat) / 2, (minLon + maxLon) / 2)
    }

    // MARK: - Neighbors

    static func neighbors(of geohash: String) -> [String] {
        guard !geohash.isEmpty else { return [] }
        let directions: [(Int, Int)] = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        guard let (lat, lon) = decode(geohash) else { return [] }
        let (latErr, lonErr) = error(for: geohash.count)
        return directions.compactMap { (dlat, dlon) in
            let newLat = lat + Double(dlat) * latErr * 2
            let newLon = lon + Double(dlon) * lonErr * 2
            guard newLat >= -90, newLat <= 90, newLon >= -180, newLon <= 180 else { return nil }
            return encode(latitude: newLat, longitude: newLon, precision: geohash.count)
        }
    }

    private static func error(for precision: Int) -> (lat: Double, lon: Double) {
        let bits = precision * 5
        let lonBits = (bits + 1) / 2
        let latBits = bits / 2
        let lonErr = 180.0 / pow(2.0, Double(lonBits))
        let latErr = 90.0 / pow(2.0, Double(latBits))
        return (latErr, lonErr)
    }

    // MARK: - Range query helpers

    /// Returns (lower, upper) bounds for a Firestore range query on the given geohash prefix
    static func range(for geohash: String) -> (lower: String, upper: String) {
        return (geohash, geohash + "~")
    }

    /// Returns the center cell + 8 neighbors for a 9-cell query
    static func nineCell(latitude: Double, longitude: Double, precision: Int) -> [String] {
        let center = encode(latitude: latitude, longitude: longitude, precision: precision)
        let surrounding = neighbors(of: center)
        return [center] + surrounding
    }
}
