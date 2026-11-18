import Foundation

/// Pure HID++ 2.0 encoding and decoding. Nothing here touches IOKit.
public enum HIDPP {
    public static let longReportID: UInt8 = 0x11
    public static let shortReportID: UInt8 = 0x10
    public static let longReportLength = 20
    public static let softwareID: UInt8 = 0x0A
    public static let slots: ClosedRange<UInt8> = 1...6

    static let hidpp1ErrorMarker: UInt8 = 0x8F
    static let hidpp2ErrorMarker: UInt8 = 0xFF

    public enum Feature: UInt16 {
        case root = 0x0000
        case deviceName = 0x0005
        case batteryStatus = 0x1000
        case unifiedBattery = 0x1004
    }

    public struct Request: Equatable, Sendable {
        public let slot: UInt8
        public let featureIndex: UInt8
        public let function: UInt8
        public let params: [UInt8]

        public init(slot: UInt8, featureIndex: UInt8, function: UInt8, params: [UInt8] = []) {
            self.slot = slot
            self.featureIndex = featureIndex
            self.function = function
            self.params = params
        }

        var functionAndSoftwareID: UInt8 { (function << 4) | HIDPP.softwareID }

        public var report: [UInt8] {
            var bytes = [HIDPP.longReportID, slot, featureIndex, functionAndSoftwareID] + params
            bytes += [UInt8](repeating: 0, count: max(0, HIDPP.longReportLength - bytes.count))
            return Array(bytes.prefix(HIDPP.longReportLength))
        }

        /// Classifies one incoming report against this request. `nil` means the report belongs
        /// to something else (stale, lagging, unsolicited) and must be discarded.
        public func interpret(_ report: [UInt8]) -> Reply? {
            guard report.count >= 5, report[1] == slot else { return nil }
            switch report[2] {
            case HIDPP.hidpp1ErrorMarker, HIDPP.hidpp2ErrorMarker:
                guard report[3] == featureIndex, report[4] == functionAndSoftwareID else { return nil }
                return .unreachable
            case featureIndex:
                guard report[0] == HIDPP.longReportID, report[3] == functionAndSoftwareID else { return nil }
                return .payload(Array(report.dropFirst(4)))
            default:
                return nil
            }
        }
    }

    public enum Reply: Equatable, Sendable {
        case payload([UInt8])
        case unreachable
    }

    // MARK: Requests

    public static func getFeature(slot: UInt8, _ feature: Feature) -> Request {
        Request(slot: slot, featureIndex: 0, function: 0,
                params: [UInt8(feature.rawValue >> 8), UInt8(feature.rawValue & 0xFF)])
    }

    // MARK: Decoding

    /// Root getFeature reply. Index 0 means the device lacks the feature.
    public static func decodeFeatureIndex(_ params: [UInt8]) -> UInt8? {
        guard let index = params.first, index != 0 else { return nil }
        return index
    }

    public static func decodeNameLength(_ params: [UInt8]) -> Int? {
        params.first.map(Int.init)
    }

    /// One DEVICE_NAME chunk. Takes at most `remaining` bytes because the last chunk is zero padded.
    public static func decodeNameChunk(_ params: [UInt8], remaining: Int) -> [UInt8] {
        Array(params.prefix(max(0, remaining)))
    }

    public static func decodeName(_ bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    public static func decodeKind(_ params: [UInt8]) -> DeviceKind {
        params.first.map(DeviceKind.init(code:)) ?? .unknown
    }

    /// Battery status reply, shared by UNIFIED_BATTERY (0x1004) getStatus and BATTERY_STATUS (0x1000)
    /// getStatus. Both put percent at [0] and the charging state at [2], with 1 and 2 both meaning charging.
    public static func decodeBattery(_ params: [UInt8]) -> (percent: Int, charge: ChargeState)? {
        guard params.count >= 3 else { return nil }
        let charge: ChargeState = switch params[2] {
        case 0: .discharging
        case 1, 2: .charging
        case 3: .full
        default: .unknown
        }
        return (min(Int(params[0]), 100), charge)
    }
}
