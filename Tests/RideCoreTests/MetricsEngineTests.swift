import Foundation
import Testing
@testable import RideCore

struct MetricsEngineTests {
    let zero = Date(timeIntervalSince1970: 1000)

    @Test func workoutDistanceStartsAtZeroAndNeverSubtractsOnReset() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(distanceMeters: 1000), source: .indoorBike, at: zero)
        #expect(engine.distanceMeters == 0)
        _ = engine.ingest(BikePacket(distanceMeters: 1010), source: .indoorBike, at: zero.addingTimeInterval(1))
        _ = engine.ingest(BikePacket(distanceMeters: 0), source: .indoorBike, at: zero.addingTimeInterval(2))
        _ = engine.ingest(BikePacket(distanceMeters: 10), source: .indoorBike, at: zero.addingTimeInterval(3))
        #expect(engine.distanceMeters == 20)
    }

    @Test func activeReconnectKeepsAuthoritativeDistance() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(distanceMeters: 1000), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(distanceMeters: 1010), source: .indoorBike, at: zero.addingTimeInterval(1))
        engine.disconnect()
        _ = engine.ingest(BikePacket(distanceMeters: 1100), source: .indoorBike, at: zero.addingTimeInterval(10))
        #expect(engine.distanceMeters == 100)
    }

    @Test func pauseExcludesMovementIncludingDisconnectedMovement() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(distanceMeters: 100), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(distanceMeters: 110), source: .indoorBike, at: zero.addingTimeInterval(1))
        engine.setActive(false)
        _ = engine.ingest(BikePacket(distanceMeters: 200), source: .indoorBike, at: zero.addingTimeInterval(10))
        engine.disconnect()
        engine.setActive(true)
        _ = engine.ingest(BikePacket(distanceMeters: 1000), source: .indoorBike, at: zero.addingTimeInterval(100))
        _ = engine.ingest(BikePacket(distanceMeters: 1010), source: .indoorBike, at: zero.addingTimeInterval(101))
        #expect(engine.distanceMeters == 20)
    }

    @Test func speedFallbackIntegratesButNeverExtrapolatesDropouts() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(speedKPH: 36), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(speedKPH: 36), source: .indoorBike, at: zero.addingTimeInterval(1))
        _ = engine.ingest(BikePacket(speedKPH: 36), source: .indoorBike, at: zero.addingTimeInterval(100))
        #expect(engine.distanceMeters == 10)
        #expect(engine.distanceMethod == .speed)
    }

    @Test func splitFTMSNotificationsDoNotDoubleCountDistance() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(speedKPH: 36, distanceMeters: 100), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(speedKPH: 36), source: .indoorBike, at: zero.addingTimeInterval(1))
        _ = engine.ingest(BikePacket(distanceMeters: 110), source: .indoorBike, at: zero.addingTimeInterval(1.1))
        _ = engine.ingest(BikePacket(powerWatts: 250), source: .indoorBike, at: zero.addingTimeInterval(1.2))
        #expect(engine.distanceMeters == 10)
        #expect(engine.power?.value == 250)
    }

    @Test func duplicateAndCorruptDistanceCountersAreNotAdded() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(distanceMeters: 100), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(distanceMeters: 100), source: .indoorBike, at: zero.addingTimeInterval(1))
        _ = engine.ingest(BikePacket(distanceMeters: 999999), source: .indoorBike, at: zero.addingTimeInterval(2))
        #expect(engine.distanceMeters == 0)
    }

    @Test func metricSourcePriorityExpiresAndFallsBack() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(powerWatts: 200), source: .indoorBike, at: zero)
        _ = engine.ingest(BikePacket(powerWatts: 300), source: .cyclingPower, at: zero.addingTimeInterval(1))
        #expect(engine.power?.value == 200)
        _ = engine.ingest(BikePacket(powerWatts: 300), source: .cyclingPower, at: zero.addingTimeInterval(6))
        #expect(engine.power?.value == 300)
        #expect(engine.power?.fresh(at: zero.addingTimeInterval(12)) == nil)
    }

    @Test func noSyntheticDistanceWithoutWheelCalibration() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(wheel: Revolution(count: 10, eventTime: 1024)), source: .speedCadence, at: zero)
        _ = engine.ingest(BikePacket(wheel: Revolution(count: 11, eventTime: 2048)), source: .speedCadence, at: zero.addingTimeInterval(1))
        #expect(engine.distanceMethod == .unavailable)
        #expect(engine.speed == nil)
    }

    @Test func calibratedPowerWheelUses2048HzClock() {
        var engine = MetricsEngine()
        engine.wheelCircumferenceMeters = 2
        engine.begin()
        _ = engine.ingest(BikePacket(wheel: Revolution(count: 10, eventTime: 2048)), source: .cyclingPower, at: zero)
        _ = engine.ingest(BikePacket(wheel: Revolution(count: 11, eventTime: 4096)), source: .cyclingPower, at: zero.addingTimeInterval(1))
        #expect(engine.speed?.value == 7.2)
    }

    @Test func crankCountAndEventTimeWrap() {
        var tracker = RevolutionTracker()
        #expect(tracker.rate(Revolution(count: 65535, eventTime: 65024), at: zero) == nil)
        #expect(tracker.rate(Revolution(count: 0, eventTime: 512), at: zero.addingTimeInterval(1)) == 1)
    }

    @Test func stoppedCrankEventuallyReportsZero() {
        var tracker = RevolutionTracker()
        _ = tracker.rate(Revolution(count: 1, eventTime: 1024), at: zero)
        _ = tracker.rate(Revolution(count: 2, eventTime: 2048), at: zero.addingTimeInterval(1))
        #expect(tracker.rate(Revolution(count: 2, eventTime: 2048), at: zero.addingTimeInterval(2)) == 1)
        #expect(tracker.rate(Revolution(count: 2, eventTime: 2048), at: zero.addingTimeInterval(5)) == 0)
    }

    @Test func longGapAndSensorResetCannotCreateImpossibleCadence() {
        var tracker = RevolutionTracker()
        _ = tracker.rate(Revolution(count: 200, eventTime: 1024), at: zero)
        #expect(tracker.rate(Revolution(count: 1, eventTime: 2048), at: zero.addingTimeInterval(1)) == nil)
        #expect(tracker.rate(Revolution(count: 100, eventTime: 3072), at: zero.addingTimeInterval(80)) == nil)
    }

    @Test func secondWorkoutClearsPreviousDistance() {
        var engine = MetricsEngine()
        engine.begin(restoringDistance: 5000)
        engine.begin()
        #expect(engine.distanceMeters == 0)
        #expect(engine.distanceMethod == .unavailable)
    }

    @Test func invalidFloatingPointMetricsAreRejected() {
        var engine = MetricsEngine()
        engine.begin()
        _ = engine.ingest(BikePacket(speedKPH: .infinity, cadenceRPM: .nan, powerWatts: 32767, distanceMeters: .nan), source: .indoorBike, at: zero)
        #expect(engine.power == nil && engine.cadence == nil && engine.speed == nil)
        #expect(engine.distanceMeters == 0)
    }

    @Test func formatsLongWorkoutsAndMiles() {
        #expect(MetricFormat.elapsed(3661) == "1:01:01")
        #expect(MetricFormat.elapsed(-1) == "00:00")
        #expect(MetricFormat.distance(1609.344, imperial: true) == "1.00")
    }
}
