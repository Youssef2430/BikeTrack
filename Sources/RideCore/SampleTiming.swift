import Foundation

public enum SampleTiming {
    /// Cumulative deltas cover the actual interval between counters. Discrete
    /// power/cadence/speed readings cover at most one second, so a returning
    /// sensor cannot fill a radio dropout with its newly observed value.
    public static func interval(previous: Date?, segmentStart: Date, end: Date,
                                cumulative: Bool) -> DateInterval? {
        let previous = max(segmentStart, previous ?? segmentStart)
        guard end >= previous else { return nil }
        if !cumulative, end.timeIntervalSince(previous) < 0.8 { return nil }
        let start = cumulative ? previous : max(previous, end.addingTimeInterval(-1))
        return DateInterval(start: start, end: end)
    }
}
