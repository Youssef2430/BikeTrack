import Foundation

public enum PacketError: Error, Equatable {
    case truncated
    case unsupportedFlags
}

private struct Bytes {
    let data: [UInt8]
    var position = 0

    init(_ data: Data) { self.data = Array(data) }

    mutating func uint(_ count: Int) throws -> UInt32 {
        guard position + count <= data.count else { throw PacketError.truncated }
        var value: UInt32 = 0
        for i in 0..<count { value |= UInt32(data[position + i]) << (i * 8) }
        position += count
        return value
    }

    mutating func u16() throws -> UInt16 { UInt16(try uint(2)) }
    mutating func s16() throws -> Int16 { Int16(bitPattern: try u16()) }
    mutating func skip(_ count: Int) throws {
        guard position + count <= data.count else { throw PacketError.truncated }
        position += count
    }
}

public struct Revolution: Equatable, Sendable {
    public var count: UInt32
    public var eventTime: UInt16
    public init(count: UInt32, eventTime: UInt16) {
        self.count = count
        self.eventTime = eventTime
    }
}

public struct BikePacket: Equatable, Sendable {
    public var speedKPH: Double?
    public var cadenceRPM: Double?
    public var powerWatts: Double?
    public var distanceMeters: Double?
    public var crank: Revolution?
    public var wheel: Revolution?

    public init(speedKPH: Double? = nil, cadenceRPM: Double? = nil,
                powerWatts: Double? = nil, distanceMeters: Double? = nil,
                crank: Revolution? = nil, wheel: Revolution? = nil) {
        self.speedKPH = speedKPH
        self.cadenceRPM = cadenceRPM
        self.powerWatts = powerWatts
        self.distanceMeters = distanceMeters
        self.crank = crank
        self.wheel = wheel
    }
}

public enum PacketSource: String, Codable, Sendable {
    case indoorBike = "2AD2", treadmill = "2ACD", cyclingPower = "2A63", speedCadence = "2A5B"

    public var priority: Int {
        switch self {
        case .indoorBike, .treadmill: 3
        case .cyclingPower: 2
        case .speedCadence: 1
        }
    }

    public var wheelClock: Double { self == .cyclingPower ? 2048 : 1024 }
}

/// Bluetooth SIG FTMS 1.0, CPS 1.1, and CSCS 1.0 measurement layouts.
/// Parse the entire advertised payload before returning anything: malformed
/// optional fields must never partially update a live workout.
public enum BluetoothPackets {
    public static func parse(_ data: Data, source: PacketSource) throws -> BikePacket {
        switch source {
        case .indoorBike: try indoorBike(data)
        case .treadmill: try treadmill(data)
        case .cyclingPower: try cyclingPower(data)
        case .speedCadence: try speedCadence(data)
        }
    }

    public static func indoorBike(_ data: Data) throws -> BikePacket {
        var b = Bytes(data)
        let f = try b.u16()
        guard f & 0xE000 == 0 else { throw PacketError.unsupportedFlags }
        var p = BikePacket()
        // More Data has inverse semantics: speed is absent when bit 0 is set.
        if f & 1 == 0 { p.speedKPH = Double(try b.u16()) / 100 }
        if f & (1 << 1) != 0 { try b.skip(2) } // average speed
        if f & (1 << 2) != 0 { p.cadenceRPM = Double(try b.u16()) / 2 }
        if f & (1 << 3) != 0 { try b.skip(2) } // average cadence
        if f & (1 << 4) != 0 { p.distanceMeters = Double(try b.uint(3)) }
        if f & (1 << 5) != 0 { try b.skip(2) } // resistance
        if f & (1 << 6) != 0 { p.powerWatts = Double(try b.s16()) }
        if f & (1 << 7) != 0 { try b.skip(2) } // average power
        if f & (1 << 8) != 0 { try b.skip(5) } // total, hourly, minute energy
        if f & (1 << 9) != 0 { try b.skip(1) } // use Watch heart rate instead
        if f & (1 << 10) != 0 { try b.skip(1) }
        if f & (1 << 11) != 0 { try b.skip(2) }
        if f & (1 << 12) != 0 { try b.skip(2) }
        return p
    }

    public static func treadmill(_ data: Data) throws -> BikePacket {
        var b = Bytes(data)
        let f = try b.u16()
        guard f & 0xE000 == 0 else { throw PacketError.unsupportedFlags }
        var p = BikePacket()
        if f & 1 == 0 { p.speedKPH = Double(try b.u16()) / 100 }
        if f & (1 << 1) != 0 { try b.skip(2) }
        if f & (1 << 2) != 0 { p.distanceMeters = Double(try b.uint(3)) }
        if f & (1 << 3) != 0 { try b.skip(4) } // incline + ramp angle
        if f & (1 << 4) != 0 { try b.skip(4) } // elevation gain
        if f & (1 << 5) != 0 { try b.skip(1) } // instant pace
        if f & (1 << 6) != 0 { try b.skip(1) }
        if f & (1 << 7) != 0 { try b.skip(5) }
        if f & (1 << 8) != 0 { try b.skip(1) }
        if f & (1 << 9) != 0 { try b.skip(1) }
        if f & (1 << 10) != 0 { try b.skip(2) }
        if f & (1 << 11) != 0 { try b.skip(2) }
        if f & (1 << 12) != 0 { try b.skip(4) } // force and power output
        return p
    }

    public static func cyclingPower(_ data: Data) throws -> BikePacket {
        var b = Bytes(data)
        let f = try b.u16()
        guard f & 0xE000 == 0 else { throw PacketError.unsupportedFlags }
        var p = BikePacket(powerWatts: Double(try b.s16()))
        if f & 1 != 0 { try b.skip(1) }
        if f & (1 << 2) != 0 { try b.skip(2) }
        if f & (1 << 4) != 0 {
            p.wheel = Revolution(count: try b.uint(4), eventTime: try b.u16())
        }
        if f & (1 << 5) != 0 {
            p.crank = Revolution(count: UInt32(try b.u16()), eventTime: try b.u16())
        }
        if f & (1 << 6) != 0 { try b.skip(4) }
        if f & (1 << 7) != 0 { try b.skip(4) }
        if f & (1 << 8) != 0 { try b.skip(3) }
        if f & (1 << 9) != 0 { try b.skip(2) }
        if f & (1 << 10) != 0 { try b.skip(2) }
        if f & (1 << 11) != 0 { try b.skip(2) }
        return p
    }

    public static func speedCadence(_ data: Data) throws -> BikePacket {
        var b = Bytes(data)
        let f = try b.uint(1)
        guard f & 0xFC == 0, f & 3 != 0 else { throw PacketError.unsupportedFlags }
        var p = BikePacket()
        if f & 1 != 0 { p.wheel = Revolution(count: try b.uint(4), eventTime: try b.u16()) }
        if f & 2 != 0 { p.crank = Revolution(count: UInt32(try b.u16()), eventTime: try b.u16()) }
        return p
    }
}
