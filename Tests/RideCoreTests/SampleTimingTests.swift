import Foundation
import Testing
@testable import RideCore

struct SampleTimingTests {
    let start = Date(timeIntervalSince1970: 1000)

    @Test func instantaneousValuesDoNotFillSensorDropouts() throws {
        let interval = try #require(SampleTiming.interval(previous: start, segmentStart: start,
                                                          end: start.addingTimeInterval(30), cumulative: false))
        #expect(interval.duration == 1)
        #expect(interval.start == start.addingTimeInterval(29))
    }

    @Test func measuredDistanceCanCoverAnObservedCounterGap() throws {
        let interval = try #require(SampleTiming.interval(previous: start, segmentStart: start,
                                                          end: start.addingTimeInterval(30), cumulative: true))
        #expect(interval.duration == 30)
    }

    @Test func pauseBoundaryTrimsSamplesAndFrequentPowerIsThrottled() throws {
        let resumed = start.addingTimeInterval(30)
        let interval = try #require(SampleTiming.interval(previous: start, segmentStart: resumed,
                                                          end: resumed.addingTimeInterval(1), cumulative: true))
        #expect(interval.start == resumed)
        #expect(SampleTiming.interval(previous: resumed, segmentStart: resumed,
                                     end: resumed.addingTimeInterval(0.1), cumulative: false) == nil)
        #expect(SampleTiming.interval(previous: resumed, segmentStart: resumed,
                                     end: start, cumulative: true) == nil)
    }
}
