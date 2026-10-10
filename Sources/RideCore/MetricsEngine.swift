import Foundation

public struct TimedMetric: Equatable, Sendable {
    public var value: Double
    public var date: Date
    public var source: PacketSource

    public func fresh(at date: Date, timeout: TimeInterval = 5) -> Double? {
        let age = date.timeIntervalSince(self.date)
        return age >= 0 && age <= timeout ? value : nil
    }
}

/// Event clocks and crank counters wrap at 16 bits. Host time is used to reject
/// ambiguous wrap counts after a long dropout and impossible sensor resets.
public struct RevolutionTracker: Sendable {
    private var previous: Revolution?
    private var receivedAt: Date?
    private var lastMovement: Date?
    private var lastRate: Double?

    public init() {}

    public mutating func rate(_ event: Revolution, at date: Date, clock: Double = 1024,
                              crank: Bool = true) -> Double? {
        defer { previous = event; receivedAt = date }
        guard let old = previous, let receivedAt else { return nil }
        let gap = date.timeIntervalSince(receivedAt)
        guard gap >= 0, gap < 65536 / clock else { lastRate = nil; return nil }
        let count = crank ? UInt32(UInt16(truncatingIfNeeded: event.count) &- UInt16(truncatingIfNeeded: old.count))
                          : (event.count >= old.count ? event.count - old.count : 0)
        let ticks = event.eventTime &- old.eventTime
        if count == 0 {
            if let lastMovement, date.timeIntervalSince(lastMovement) < 3 { return lastRate }
            lastRate = 0
            return 0
        }
        guard ticks > 0 else { return nil }
        let rate = Double(count) * clock / Double(ticks)
        guard rate <= (crank ? 5 : 40) else { lastRate = nil; return nil }
        lastMovement = date
        lastRate = rate
        return rate
    }
}

public enum DistanceMethod: String, Codable, Sendable {
    case unavailable, machine, speed, wheel

    public var label: String {
        switch self {
        case .unavailable: "No distance source"
        case .machine: "From equipment"
        case .speed: "From equipment speed"
        case .wheel: "From wheel size"
        }
    }
}

public struct MetricsUpdate: Sendable {
    public var power: Double?
    public var cadence: Double?
    public var speed: Double?
    public var distanceDelta: Double = 0
}

public struct MetricsEngine: Sendable {
    public private(set) var power: TimedMetric?
    public private(set) var cadence: TimedMetric?
    public private(set) var speed: TimedMetric?
    public private(set) var distanceMeters: Double = 0
    public private(set) var distanceMethod: DistanceMethod = .unavailable
    public private(set) var active = false
    public var wheelCircumferenceMeters: Double?

    private var cranks: [PacketSource: RevolutionTracker] = [:]
    private var wheels: [PacketSource: RevolutionTracker] = [:]
    private var counter: Double?
    private var counterDate: Date?
    private var speedDate: Date?
    private var lastSpeed: Double?
    private var speedSource: PacketSource?

    public init() {}

    public mutating func begin(restoringDistance: Double = 0, restoringMethod: DistanceMethod = .unavailable) {
        distanceMeters = max(0, restoringDistance)
        distanceMethod = restoringMethod
        setActive(true)
    }

    public mutating func setActive(_ active: Bool) {
        self.active = active
        counter = nil
        counterDate = nil
        speedDate = nil
        lastSpeed = nil
        speedSource = nil
    }

    public mutating func disconnect() {
        power = nil; cadence = nil; speed = nil
        cranks.removeAll(); wheels.removeAll()
        speedDate = nil; lastSpeed = nil
        // Retain the machine counter: it can account for distance during a
        // connection gap. A reset is detected in ingest, not subtracted.
    }

    private func accepted(_ metric: TimedMetric?, source: PacketSource, at date: Date) -> Bool {
        guard let metric, metric.fresh(at: date) != nil else { return true }
        return source.priority >= metric.source.priority
    }

    public mutating func ingest(_ packet: BikePacket, source: PacketSource, at date: Date) -> MetricsUpdate {
        var p = packet
        var update = MetricsUpdate()
        if let crank = p.crank {
            var tracker = cranks[source] ?? RevolutionTracker()
            if let rate = tracker.rate(crank, at: date) { p.cadenceRPM = rate * 60 }
            cranks[source] = tracker
        }
        var wheelSpeed = false
        if let wheel = p.wheel, let circumference = wheelCircumferenceMeters,
           circumference > 0, circumference <= 5 {
            var tracker = wheels[source] ?? RevolutionTracker()
            if let rate = tracker.rate(wheel, at: date, clock: source.wheelClock, crank: false) {
                p.speedKPH = rate * circumference * 3.6
                wheelSpeed = true
            }
            wheels[source] = tracker
        }
        if let watts = p.powerWatts, watts.isFinite, (-32767...5000).contains(watts), accepted(power, source: source, at: date) {
            let value = max(0, watts)
            power = TimedMetric(value: value, date: date, source: source)
            update.power = value
        }
        if let rpm = p.cadenceRPM, rpm.isFinite, (0...300).contains(rpm), accepted(cadence, source: source, at: date) {
            cadence = TimedMetric(value: rpm, date: date, source: source)
            update.cadence = rpm
        }
        if let kph = p.speedKPH, kph.isFinite, (0...200).contains(kph), accepted(speed, source: source, at: date) {
            speed = TimedMetric(value: kph, date: date, source: source)
            update.speed = kph
        }
        if let raw = p.distanceMeters, raw.isFinite, raw >= 0 {
            if active {
                distanceMethod = .machine
                if let counter, let counterDate {
                    let dt = date.timeIntervalSince(counterDate)
                    let delta = raw - counter
                    if dt > 0, delta >= 0, delta <= dt * 200 / 3.6 + 5 {
                        update.distanceDelta = delta
                    }
                }
            }
            counter = raw
            counterDate = date
        } else if active, distanceMethod != .machine, let kph = update.speed {
            distanceMethod = wheelSpeed ? .wheel : .speed
            if let speedDate, let lastSpeed, speedSource == source {
                let dt = date.timeIntervalSince(speedDate)
                // Never extrapolate stale speed across a radio dropout.
                if dt > 0, dt <= 5 { update.distanceDelta = (lastSpeed + kph) / 2 / 3.6 * dt }
            }
        }
        if let kph = update.speed {
            speedDate = date; lastSpeed = kph; speedSource = source
        }
        if active { distanceMeters += update.distanceDelta }
        else { update.distanceDelta = 0 }
        return update
    }
}
