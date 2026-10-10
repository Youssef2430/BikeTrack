import Foundation
import Testing
@testable import RideCore

struct BluetoothPacketTests {
    @Test func indoorBikeDecodesMetricsInSpecOrder() throws {
        // 30 km/h, 90 rpm, 1000 m, 250 W. Flags: cadence, distance, power.
        let packet = try BluetoothPackets.indoorBike(Data([0x54, 0, 0xB8, 0x0B, 0xB4, 0, 0xE8, 3, 0, 0xFA, 0]))
        #expect(packet.speedKPH == 30)
        #expect(packet.cadenceRPM == 90)
        #expect(packet.distanceMeters == 1000)
        #expect(packet.powerWatts == 250)
    }

    @Test func moreDataOmitsSpeedWithoutShiftingOtherFields() throws {
        let packet = try BluetoothPackets.indoorBike(Data([0x45, 0, 0xB5, 0, 0xF6, 0xFF]))
        #expect(packet.speedKPH == nil)
        #expect(packet.cadenceRPM == 90.5)
        #expect(packet.powerWatts == -10)
    }

    @Test func everyOptionalBikeFieldIsConsumed() throws {
        let full = Data([0xFE, 0x1F, 0xB8, 0x0B, 0, 0, 180, 0, 0, 0,
                         0x56, 0x34, 0x12, 0, 0, 250, 0, 0, 0,
                         0, 0, 0, 0, 0, 140, 0, 0, 0, 0, 0])
        let packet = try BluetoothPackets.indoorBike(full)
        #expect(packet.distanceMeters == 0x123456)
        #expect(packet.powerWatts == 250)
        for count in 0..<full.count {
            #expect(throws: PacketError.truncated) { try BluetoothPackets.indoorBike(full.prefix(count)) }
        }
    }

    @Test func treadmillIncludesInclinationAndOtherOptionalFields() throws {
        let packet = try BluetoothPackets.treadmill(Data([0x0C, 0, 0xE8, 3, 0xE8, 3, 0, 50, 0, 0, 0]))
        #expect(packet.speedKPH == 10)
        #expect(packet.distanceMeters == 1000)
        #expect(packet.cadenceRPM == nil)
    }

    @Test func treadmillContinuationHasNoSpeed() throws {
        let packet = try BluetoothPackets.treadmill(Data([5, 0, 0xFF, 0xFF, 0]))
        #expect(packet.distanceMeters == 65535)
        #expect(packet.speedKPH == nil)
    }

    @Test func cyclingPowerSkipsPedalAndTorqueBeforeRevolutions() throws {
        let data = Data([0x35, 0, 0x2C, 1, 50, 0, 0, 100, 0, 0, 0, 0, 8, 20, 0, 0, 4])
        let packet = try BluetoothPackets.cyclingPower(data)
        #expect(packet.powerWatts == 300)
        #expect(packet.wheel == Revolution(count: 100, eventTime: 2048))
        #expect(packet.crank == Revolution(count: 20, eventTime: 1024))
    }

    @Test func combinedCSCDecodesBothCounters() throws {
        let packet = try BluetoothPackets.speedCadence(Data([3, 0x78, 0x56, 0x34, 0x12, 0xFF, 0xFF, 7, 0, 0, 4]))
        #expect(packet.wheel?.count == 0x12345678)
        #expect(packet.wheel?.eventTime == 65535)
        #expect(packet.crank?.count == 7)
        #expect(packet.crank?.eventTime == 1024)
    }

    @Test func slicedDataDoesNotAssumeZeroBasedIndices() throws {
        let data = Data([99, 99, 0, 0, 0xFA, 0]).dropFirst(2)
        #expect(try BluetoothPackets.cyclingPower(data).powerWatts == 250)
    }

    @Test func reservedFlagsAreRejected() {
        #expect(throws: PacketError.unsupportedFlags) { try BluetoothPackets.indoorBike(Data([0, 0x80, 0, 0])) }
        #expect(throws: PacketError.unsupportedFlags) { try BluetoothPackets.speedCadence(Data([0])) }
    }

    @Test func allBikeFlagCombinationsParseOrThrowWithoutCrashing() throws {
        for flags in UInt16(0)..<8192 {
            var bytes: [UInt8] = [UInt8(flags & 0xFF), UInt8(flags >> 8)]
            if flags & 1 == 0 { bytes += [0, 0] }
            let sizes = [2, 2, 2, 3, 2, 2, 2, 5, 1, 1, 2, 2]
            for (offset, size) in sizes.enumerated() where flags & (1 << (offset + 1)) != 0 {
                bytes += Array(repeating: 0, count: size)
            }
            _ = try BluetoothPackets.indoorBike(Data(bytes))
            if bytes.count > 2 {
                #expect(throws: PacketError.truncated) { try BluetoothPackets.indoorBike(Data(bytes.dropLast())) }
            }
        }
    }

    @Test func allTreadmillFlagCombinationsHaveCorrectLengths() throws {
        for flags in UInt16(0)..<8192 {
            var bytes: [UInt8] = [UInt8(flags & 0xFF), UInt8(flags >> 8)]
            if flags & 1 == 0 { bytes += [0, 0] }
            let sizes = [2, 3, 4, 4, 1, 1, 5, 1, 1, 2, 2, 4]
            for (offset, size) in sizes.enumerated() where flags & (1 << (offset + 1)) != 0 {
                bytes += Array(repeating: 0, count: size)
            }
            _ = try BluetoothPackets.treadmill(Data(bytes))
            if bytes.count > 2 {
                #expect(throws: PacketError.truncated) { try BluetoothPackets.treadmill(Data(bytes.dropLast())) }
            }
        }
    }
}
