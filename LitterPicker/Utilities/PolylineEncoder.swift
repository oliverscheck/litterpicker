import Foundation
import CoreLocation

enum PolylineEncoder {
    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var prevLat: Int = 0
        var prevLng: Int = 0
        for coord in coordinates {
            let lat = Int(round(coord.latitude * 1e5))
            let lng = Int(round(coord.longitude * 1e5))
            result += encodeValue(lat - prevLat)
            result += encodeValue(lng - prevLng)
            prevLat = lat
            prevLng = lng
        }
        return result
    }

    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let bytes = Array(encoded.utf8)
        var i = 0
        var lat = 0
        var lng = 0
        while i < bytes.count {
            lat += decodeChunk(bytes: bytes, index: &i)
            if i >= bytes.count { break }
            lng += decodeChunk(bytes: bytes, index: &i)
            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }
        return coordinates
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        var result = ""
        while v >= 0x20 {
            result.append(Character(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!))
            v >>= 5
        }
        result.append(Character(UnicodeScalar(v + 63)!))
        return result
    }

    private static func decodeChunk(bytes: [UInt8], index: inout Int) -> Int {
        var result = 0
        var shift = 0
        var byte: Int
        repeat {
            byte = Int(bytes[index]) - 63
            index += 1
            result |= (byte & 0x1f) << shift
            shift += 5
        } while byte >= 0x20 && index < bytes.count
        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }
}
