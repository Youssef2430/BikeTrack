import Foundation
import Testing
@testable import RideCore

struct WorkoutAnalyticsTests {
    let profile = TrainingProfile(maximumHeartRate: 200, functionalThresholdPower: 200)

    @Test func boundariesAreGaplessAndMissingIsNotRecovery() {
        for (value, zone) in [(99.9, 0), (100, 1), (120, 2), (140, 3), (160, 4), (180, 5), (220, 5)] {
            #expect(profile.zone(for: value, metric: .heartRate)?.id == zone)
        }
        for (value, zone) in [(0.0, 1), (110, 1), (110.1, 2), (150, 2), (150.1, 3), (180, 3), (180.1, 4), (210, 4), (210.1, 5), (240, 5), (240.1, 6), (300, 6), (300.1, 7)] {
            #expect(profile.zone(for: value, metric: .power)?.id == zone)
        }
        #expect(profile.zone(for: nil, metric: .power) == nil)
        #expect(profile.zone(for: 0, metric: .heartRate) == nil)
        #expect(profile.zone(for: .nan, metric: .heartRate) == nil)
        #expect(TrainingProfile(maximumHeartRate: -1, functionalThresholdPower: .infinity).zones(for: .power).isEmpty)
    }

    @Test func accountsForZoneTransitionsAndNeverDoubleCountsTicks() {
        var recorder = AnalyticsRecorder(profile: profile)
        recorder.observe(100, metric: .power, at: 0)
        recorder.advance(to: 2)
        recorder.advance(to: 2)
        recorder.observe(200, metric: .power, at: 3)
        recorder.advance(to: 5)
        let power = recorder.snapshot.power
        #expect(power.zoneSeconds[1] == 3)
        #expect(power.zoneSeconds[4] == 2)
        #expect(power.recordedSeconds == 5)
        #expect(power.average == 140)
        #expect(power.peak == 200)
    }

    @Test func staleSensorsPausesAndRecoveryDoNotInventTime() throws {
        var recorder = AnalyticsRecorder(profile: profile)
        recorder.observe(140, metric: .heartRate, at: 0)
        recorder.observe(200, metric: .power, at: 0)
        recorder.advance(to: 30)
        #expect(recorder.snapshot.heartRate.recordedSeconds == 20)
        #expect(recorder.snapshot.power.recordedSeconds == 5)
        recorder.observe(210, metric: .power, at: 30)
        recorder.suspend(at: 32)
        recorder.advance(to: 40)
        recorder.observe(100, metric: .power, at: 40)
        recorder.advance(to: 41)
        #expect(recorder.snapshot.power.recordedSeconds == 8)
        #expect(Set(recorder.snapshot.power.points.map(\.segment)).count == 3)
        let data = try JSONEncoder().encode(recorder.snapshot)
        let snapshot = try JSONDecoder().decode(WorkoutAnalytics.self, from: data)
        var restored = AnalyticsRecorder(restoring: snapshot)
        restored.advance(to: 60)
        #expect(restored.snapshot.power.recordedSeconds == 8)
        restored.observe(200, metric: .power, at: 60)
        restored.advance(to: 62)
        #expect(restored.snapshot.power.recordedSeconds == 10)
        #expect(restored.profile == profile)
    }

    @Test func disconnectAndLateSamplesDoNotExtendCoverage() {
        var recorder = AnalyticsRecorder(profile: profile)
        recorder.observe(100, metric: .power, at: 1)
        recorder.disconnectPower(at: 3)
        recorder.advance(to: 10)
        recorder.observe(999, metric: .power, at: 2)
        recorder.observe(.nan, metric: .power, at: 10)
        #expect(recorder.snapshot.power.recordedSeconds == 2)
        #expect(recorder.snapshot.power.peak == 100)
    }

    @Test func delayedHeartRateExpiresAtTheOriginalSampleTime() {
        var recorder = AnalyticsRecorder(profile: profile)
        recorder.observe(140, metric: .heartRate, at: 10, age: 8)
        recorder.advance(to: 30)
        #expect(recorder.snapshot.heartRate.recordedSeconds == 12)
        recorder.observe(160, metric: .heartRate, at: 30, age: 20)
        recorder.advance(to: 40)
        #expect(recorder.snapshot.heartRate.recordedSeconds == 12)
    }

    @Test func longWorkoutsBoundChartStorageWithoutLosingTotals() {
        var recorder = AnalyticsRecorder(profile: profile)
        for second in 0..<20_000 { recorder.observe(200, metric: .power, at: Double(second)) }
        recorder.advance(to: 20_000)
        #expect(recorder.snapshot.power.points.count <= 600)
        #expect(recorder.snapshot.power.points.first?.elapsed == 0)
        #expect(recorder.snapshot.power.points.last?.elapsed == 19_999)
        #expect(recorder.snapshot.power.recordedSeconds == 20_000)
        #expect(recorder.snapshot.power.zoneSeconds[4] == 20_000)
    }

    @Test func legacyRecordsDecodeAndNewRecordsKeepTheirProfile() throws {
        let record = WorkoutRecord(startedAt: Date(), activity: .cycling, duration: 60, distanceMeters: 0, distanceMethod: .unavailable, analytics: WorkoutAnalytics(profile: profile))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        json.removeValue(forKey: "analytics")
        let legacy = try JSONDecoder().decode(WorkoutRecord.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.analytics == nil)
        #expect(try JSONDecoder().decode(WorkoutRecord.self, from: JSONEncoder().encode(record)) == record)
    }
}
