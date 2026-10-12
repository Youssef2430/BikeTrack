import Foundation
import RideCore

/// Unset values fall back to typical defaults, so zones work before any setup.
/// Saved values and custom zone starts replace them for the next workout.
enum TrainingSettings {
    static var profile: TrainingProfile {
        let defaults = UserDefaults.standard
        return TrainingProfile(maximumHeartRate: baseline(defaults.double(forKey: baselineKey(.heartRate)), for: .heartRate),
                               functionalThresholdPower: baseline(defaults.double(forKey: baselineKey(.power)), for: .power),
                               heartRateEdges: decode(defaults.string(forKey: edgesKey(.heartRate))),
                               powerEdges: decode(defaults.string(forKey: edgesKey(.power))))
    }
    static let demoProfile = TrainingProfile(maximumHeartRate: 190, functionalThresholdPower: 240)

    static func baselineKey(_ metric: ZoneMetric) -> String { metric == .heartRate ? "maximumHeartRate" : "ftp" }
    static func edgesKey(_ metric: ZoneMetric) -> String { metric == .heartRate ? "heartRateZoneEdges" : "powerZoneEdges" }

    static func defaultBaseline(for metric: ZoneMetric) -> Double {
        metric == .heartRate ? TrainingProfile.defaultMaximumHeartRate : TrainingProfile.defaultFunctionalThresholdPower
    }

    static func baseline(_ saved: Double, for metric: ZoneMetric) -> Double {
        saved > 0 ? saved : defaultBaseline(for: metric)
    }

    static func decode(_ text: String?) -> [Double]? {
        guard let text, !text.isEmpty else { return nil }
        let edges = text.split(separator: ",").compactMap { Double($0) }
        return edges.isEmpty ? nil : edges
    }

    static func encode(_ edges: [Double]) -> String { edges.map { String($0) }.joined(separator: ",") }
}
