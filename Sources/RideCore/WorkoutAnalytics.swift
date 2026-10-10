import Foundation

public struct TrendPoint: Codable, Equatable, Sendable {
    public let elapsed: TimeInterval
    public let value: Double
    public let segment: Int
}

public struct MetricTimeline: Codable, Equatable, Sendable {
    public var points: [TrendPoint] = []
    public var zoneSeconds: [Int: TimeInterval] = [:]
    public var recordedSeconds: TimeInterval = 0
    public var weightedTotal: Double = 0
    public var peak: Double?
    public var average: Double? { recordedSeconds > 0 ? weightedTotal / recordedSeconds : nil }
    public init() {}
}

public struct WorkoutAnalytics: Codable, Equatable, Sendable {
    public var profile: TrainingProfile
    public var heartRate: MetricTimeline
    public var power: MetricTimeline
    public init(profile: TrainingProfile = TrainingProfile(), heartRate: MetricTimeline = MetricTimeline(), power: MetricTimeline = MetricTimeline()) {
        self.profile = profile; self.heartRate = heartRate; self.power = power
    }
    public func timeline(for metric: ZoneMetric) -> MetricTimeline { metric == .heartRate ? heartRate : power }
}

/// Integrates observed values on the active-workout clock. Gaps are capped at
/// each sensor's freshness limit; pauses and recovery clear the held readings.
/// Chart thinning never changes the exact accumulated durations or averages.
public struct AnalyticsRecorder: Sendable {
    public let profile: TrainingProfile
    private var heartRate: MetricRecorder
    private var power: MetricRecorder
    public init(profile: TrainingProfile) { self.init(restoring: WorkoutAnalytics(profile: profile)) }
    public init(restoring snapshot: WorkoutAnalytics) {
        profile = snapshot.profile
        heartRate = MetricRecorder(metric: .heartRate, timeline: snapshot.heartRate)
        power = MetricRecorder(metric: .power, timeline: snapshot.power)
    }
    public var snapshot: WorkoutAnalytics { WorkoutAnalytics(profile: profile, heartRate: heartRate.timeline, power: power.timeline) }
    public mutating func observe(_ value: Double, metric: ZoneMetric, at elapsed: TimeInterval, age: TimeInterval = 0) {
        if metric == .heartRate { heartRate.observe(value, at: elapsed, age: age, profile: profile) }
        else { power.observe(value, at: elapsed, age: age, profile: profile) }
    }
    public mutating func advance(to elapsed: TimeInterval) {
        heartRate.advance(to: elapsed, profile: profile); power.advance(to: elapsed, profile: profile)
    }
    public mutating func suspend(at elapsed: TimeInterval) {
        heartRate.suspend(at: elapsed, profile: profile); power.suspend(at: elapsed, profile: profile)
    }
    public mutating func disconnectPower(at elapsed: TimeInterval) { power.suspend(at: elapsed, profile: profile) }
}

private struct MetricRecorder: Sendable {
    let metric: ZoneMetric
    var timeline: MetricTimeline
    private var held: (value: Double, elapsed: TimeInterval, expires: TimeInterval)?
    private var cursor: TimeInterval
    private var segment: Int
    init(metric: ZoneMetric, timeline: MetricTimeline) {
        self.metric = metric; self.timeline = timeline
        cursor = timeline.points.last?.elapsed ?? 0
        segment = (timeline.points.last?.segment ?? -1) + 1
    }
    mutating func observe(_ value: Double, at elapsed: TimeInterval, age: TimeInterval, profile: TrainingProfile) {
        guard elapsed.isFinite, elapsed >= cursor, value.isFinite, age.isFinite, age >= 0, age < metric.freshness,
              metric == .heartRate ? (value > 0 && value <= 300) : (value >= 0 && value <= 5000) else { return }
        // Duplicate or late sensor notifications must not renew a stale reading.
        if let held, elapsed <= held.elapsed { return }
        advance(to: elapsed, profile: profile)
        if let held, elapsed > held.expires { segment += 1 }
        held = (value, elapsed, elapsed + metric.freshness - age)
        cursor = elapsed
        timeline.peak = max(timeline.peak ?? value, value)
        timeline.points.append(TrendPoint(elapsed: elapsed, value: value, segment: segment))
        if timeline.points.count > 600 {
            let last = timeline.points.last!
            timeline.points = stride(from: 0, to: timeline.points.count - 1, by: 2).map { timeline.points[$0] }
            timeline.points.append(last)
        }
    }
    mutating func advance(to elapsed: TimeInterval, profile: TrainingProfile) {
        guard elapsed.isFinite, elapsed >= cursor else { return }
        if let held {
            let duration = max(0, min(elapsed, held.expires) - cursor)
            timeline.recordedSeconds += duration
            timeline.weightedTotal += held.value * duration
            if let zone = profile.zone(for: held.value, metric: metric) { timeline.zoneSeconds[zone.id, default: 0] += duration }
        }
        cursor = elapsed
    }
    mutating func suspend(at elapsed: TimeInterval, profile: TrainingProfile) {
        advance(to: elapsed, profile: profile)
        held = nil
        segment += 1
    }
}
