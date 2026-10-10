import Foundation

public enum ActivityKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case cycling, running, walking
    public var id: Self { self }
    public var title: String {
        switch self { case .cycling: "Indoor ride"; case .running: "Indoor run"; case .walking: "Indoor walk" }
    }
    public var symbol: String {
        switch self { case .cycling: "figure.indoor.cycle"; case .running: "figure.run"; case .walking: "figure.walk" }
    }
}

public struct WorkoutRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var activity: ActivityKind
    public var duration: TimeInterval
    public var distanceMeters: Double
    public var distanceMethod: DistanceMethod
    public var averagePower: Double?
    public var averageHeartRate: Double?
    public var energyKcal: Double?
    public var savedToHealth: Bool
    public var isDemo: Bool
    public var analytics: WorkoutAnalytics?

    public init(id: UUID = UUID(), startedAt: Date, activity: ActivityKind,
                duration: TimeInterval, distanceMeters: Double, distanceMethod: DistanceMethod,
                averagePower: Double? = nil, averageHeartRate: Double? = nil,
                energyKcal: Double? = nil, savedToHealth: Bool = false, isDemo: Bool = false,
                analytics: WorkoutAnalytics? = nil) {
        self.id = id; self.startedAt = startedAt; self.activity = activity
        self.duration = duration; self.distanceMeters = distanceMeters
        self.distanceMethod = distanceMethod; self.averagePower = averagePower
        self.averageHeartRate = averageHeartRate; self.energyKcal = energyKcal
        self.savedToHealth = savedToHealth; self.isDemo = isDemo
        self.analytics = analytics
    }
}

public enum MetricFormat {
    public static func elapsed(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.isFinite ? duration : 0))
        if seconds >= 3600 { return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    public static func distance(_ meters: Double, imperial: Bool) -> String {
        String(format: "%.2f", meters / (imperial ? 1609.344 : 1000))
    }
}
