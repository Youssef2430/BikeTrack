import Foundation

public enum ZoneMetric: String, Codable, CaseIterable, Sendable {
    case heartRate, power
    public var title: String { self == .heartRate ? "Heart rate" : "Power" }
    public var unit: String { self == .heartRate ? "bpm" : "W" }
    public var freshness: TimeInterval { self == .heartRate ? 20 : 5 }
}

/// A workout keeps its own profile, so changing settings never rewrites history.
public struct TrainingProfile: Codable, Equatable, Sendable {
    public static let defaultMaximumHeartRate: Double = 190
    public static let defaultFunctionalThresholdPower: Double = 200

    public var maximumHeartRate: Double?
    public var functionalThresholdPower: Double?
    /// Zone starts as fractions of the baseline. Nil uses the standard scheme.
    public var heartRateEdges: [Double]?
    public var powerEdges: [Double]?

    public init(maximumHeartRate: Double? = nil, functionalThresholdPower: Double? = nil,
                heartRateEdges: [Double]? = nil, powerEdges: [Double]? = nil) {
        self.maximumHeartRate = maximumHeartRate.flatMap { $0.isFinite && (80...240).contains($0) ? $0 : nil }
        self.functionalThresholdPower = functionalThresholdPower.flatMap { $0.isFinite && (20...1000).contains($0) ? $0 : nil }
        self.heartRateEdges = heartRateEdges.flatMap { Self.isValid($0, for: .heartRate) ? $0 : nil }
        self.powerEdges = powerEdges.flatMap { Self.isValid($0, for: .power) ? $0 : nil }
    }

    public func baseline(for metric: ZoneMetric) -> Double? {
        metric == .heartRate ? maximumHeartRate : functionalThresholdPower
    }

    public static func defaultEdges(for metric: ZoneMetric) -> [Double] {
        metric == .heartRate ? [0.5, 0.6, 0.7, 0.8, 0.9] : [0.55, 0.75, 0.90, 1.05, 1.20, 1.50]
    }

    /// Custom starts must keep every zone, rise strictly, and stay within a plausible range.
    public static func isValid(_ edges: [Double], for metric: ZoneMetric) -> Bool {
        edges.count == defaultEdges(for: metric).count
            && edges.allSatisfy { $0.isFinite && $0 > 0 && $0 < 3 }
            && zip(edges, edges.dropFirst()).allSatisfy { $0 < $1 }
    }

    public func edges(for metric: ZoneMetric) -> [Double] {
        let custom = metric == .heartRate ? heartRateEdges : powerEdges
        return custom.flatMap { Self.isValid($0, for: metric) ? $0 : nil } ?? Self.defaultEdges(for: metric)
    }

    public func zones(for metric: ZoneMetric) -> [TrainingZone] {
        guard let baseline = baseline(for: metric) else { return [] }
        let names = metric == .heartRate
            ? ["Below Z1", "Recovery", "Endurance", "Aerobic", "Threshold", "Maximum"]
            : ["Recovery", "Endurance", "Tempo", "Threshold", "VO₂ max", "Anaerobic", "Sprint"]
        // Hundredths keep percentages of the baseline free of floating-point residue.
        let edges = edges(for: metric).map { ($0 * baseline * 100).rounded() / 100 }
        return names.indices.map { index in
            TrainingZone(id: metric == .heartRate ? index : index + 1, name: names[index],
                         lowerBound: index == 0 ? 0 : edges[index - 1],
                         upperBound: index < edges.count ? edges[index] : nil,
                         upperInclusive: metric == .power)
        }
    }

    public func zone(for value: Double?, metric: ZoneMetric) -> TrainingZone? {
        guard let value, value.isFinite, value >= 0, metric != .heartRate || value > 0 else { return nil }
        return zones(for: metric).first { zone in
            guard let upper = zone.upperBound else { return true }
            return zone.upperInclusive ? value <= upper : value < upper
        }
    }
}

public struct TrainingZone: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let lowerBound: Double
    public let upperBound: Double?
    public let upperInclusive: Bool
    public var label: String { id == 0 ? "Below Z1" : "Zone \(id)" }
    /// Explicit inequalities also describe fractional sensor values without gaps.
    public var range: String {
        func number(_ value: Double) -> String { String(format: value == value.rounded() ? "%.0f" : "%.1f", value) }
        if lowerBound == 0, let upperBound { return "\(upperInclusive ? "≤" : "<")\(number(upperBound))" }
        if let upperBound { return "\(upperInclusive ? ">" : "≥")\(number(lowerBound)) – \(upperInclusive ? "≤" : "<")\(number(upperBound))" }
        return "\(upperInclusive ? ">" : "≥")\(number(lowerBound))"
    }
}
