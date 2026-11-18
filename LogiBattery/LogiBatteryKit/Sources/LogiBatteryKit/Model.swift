import Foundation

/// HID++ 2.0 device type as reported by the DEVICE_NAME feature (0x0005, function 2).
public enum DeviceKind: UInt8, Codable, Hashable, Sendable {
    case keyboard = 0
    case remote = 1
    case numpad = 2
    case mouse = 3
    case trackpad = 4
    case trackball = 5
    case presenter = 6
    case receiver = 7
    case unknown = 255

    public init(code: UInt8) {
        self = DeviceKind(rawValue: code) ?? .unknown
    }
}

public enum ChargeState: String, Codable, Hashable, Sendable {
    case discharging
    case charging
    case full
    case unknown
}

public struct DeviceBattery: Codable, Hashable, Identifiable, Sendable {
    public let slot: UInt8
    public let name: String
    public let kind: DeviceKind
    public let percent: Int
    public let charge: ChargeState

    public var id: UInt8 { slot }

    public init(slot: UInt8, name: String, kind: DeviceKind, percent: Int, charge: ChargeState) {
        self.slot = slot
        self.name = name
        self.kind = kind
        self.percent = percent
        self.charge = charge
    }
}

/// A sleeping device keeps its last value as `.stale` instead of vanishing.
public enum Reading: Codable, Hashable, Identifiable, Sendable {
    case live(DeviceBattery, at: Date)
    case stale(DeviceBattery, lastSeen: Date)

    public var battery: DeviceBattery {
        switch self {
        case .live(let battery, _), .stale(let battery, _): battery
        }
    }

    public var id: UInt8 { battery.slot }

    public var isStale: Bool {
        if case .stale = self { true } else { false }
    }

    public var date: Date {
        switch self {
        case .live(_, let at): at
        case .stale(_, let lastSeen): lastSeen
        }
    }
}
