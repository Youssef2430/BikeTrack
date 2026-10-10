import XCTest
import HealthKit
import RideCore
@testable import BikeTrack

final class HealthPersistenceTests: XCTestCase {
    @MainActor
    func testEquipmentSamplesPauseAndSaveThroughHealthKit() async throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Generated measurements must never be written to a physical Watch.")
        #else
        let health = HKHealthStore()
        guard health.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            throw XCTSkip("Run the simulator Health permission UI test first.")
        }
        let controller = WorkoutController.shared
        await controller.start(activity: .cycling)
        XCTAssertEqual(controller.phase, .running)

        func packet(_ distance: UInt32) throws {
            // Standard FTMS: 36 km/h, 90 rpm, cumulative distance, 200 W.
            let bytes = Data([0x54, 0, 0x10, 0x0E, 180, 0,
                              UInt8(distance & 255), UInt8((distance >> 8) & 255), UInt8((distance >> 16) & 255),
                              200, 0])
            controller.bluetooth.onPacket?(try BluetoothPackets.indoorBike(bytes), .indoorBike, Date())
        }
        try packet(1000)
        try await Task.sleep(for: .seconds(1))
        try packet(1010)
        controller.pauseOrResume()
        try await wait(controller, for: .paused)
        try packet(1510) // 500 meters during the pause must be excluded.
        controller.pauseOrResume()
        try await wait(controller, for: .running)
        try packet(1520) // Rebase after resuming.
        try await Task.sleep(for: .seconds(1))
        try packet(1530)
        controller.endAndSave()
        try await wait(controller, for: .summary)
        let summary = try XCTUnwrap(controller.summary)
        XCTAssertTrue(summary.savedToHealth)
        XCTAssertEqual(summary.distanceMeters, 20, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.averagePower), 200, accuracy: 0.001)

        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                                   allowedValues: ["biketrack.workout.\(summary.id.uuidString)"])
        let saved: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            health.execute(HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 10, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKWorkout] ?? []) }
            })
        }
        XCTAssertEqual(saved.count, 1)
        let workout = try XCTUnwrap(saved.first)
        let distance = workout.statistics(for: HKQuantityType(.distanceCycling))?.sumQuantity()?.doubleValue(for: .meter())
        let cadence = workout.statistics(for: HKQuantityType(.cyclingCadence))?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        XCTAssertEqual(try XCTUnwrap(distance), 20, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(cadence), 90, accuracy: 0.001)
        controller.reset()
        #endif
    }

    @MainActor
    private func wait(_ controller: WorkoutController, for phase: WorkoutPhase) async throws {
        for _ in 0..<150 {
            if controller.phase == phase { return }
            if controller.phase == .saveFailed { XCTFail(controller.errorMessage ?? "Save failed"); return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Expected \(phase), got \(controller.phase): \(controller.errorMessage ?? "no error")")
    }

    func testCyclingCadenceAndSpeedUseHealthKitCompatibleUnits() throws {
        let start = Date()
        let cadence = try SampleDraft(identifier: HKQuantityTypeIdentifier.cyclingCadence.rawValue,
                                      unit: "count/min", value: 90, start: start, end: start.addingTimeInterval(1))
        let speed = try SampleDraft(identifier: HKQuantityTypeIdentifier.cyclingSpeed.rawValue,
                                    unit: "m/s", value: 10, start: start, end: start.addingTimeInterval(1))
        XCTAssertEqual(try cadence.sample().quantity.doubleValue(for: .count().unitDivided(by: .minute())), 90)
        XCTAssertEqual(try speed.sample().quantity.doubleValue(for: .meter().unitDivided(by: .second())), 10)
    }

    func testSampleIdentitySurvivesDiskRoundTripAndRepeatedRetries() throws {
        let draft = try SampleDraft(identifier: HKQuantityTypeIdentifier.cyclingPower.rawValue,
                                    unit: "W", value: 250,
                                    start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 1001))
        let first = try draft.sample()
        let data = try JSONEncoder().encode(draft)
        let reloaded = try JSONDecoder().decode(SampleDraft.self, from: data)
        let retry = try reloaded.sample()
        XCTAssertEqual(first.uuid, retry.uuid)
        XCTAssertEqual(first.quantity.doubleValue(for: .watt()), retry.quantity.doubleValue(for: .watt()))
        XCTAssertEqual(first.metadata?[HKMetadataKeySyncIdentifier] as? String, retry.metadata?[HKMetadataKeySyncIdentifier] as? String)
        XCTAssertEqual(first.startDate, retry.startDate)
        XCTAssertEqual(first.endDate, retry.endDate)
        XCTAssertEqual(retry.uuid, try reloaded.sample().uuid)
    }

    func testSamplesHaveDistinctIdentities() throws {
        let start = Date()
        let a = try SampleDraft(identifier: HKQuantityTypeIdentifier.distanceCycling.rawValue, unit: "m", value: 10, start: start, end: start.addingTimeInterval(1))
        let b = try SampleDraft(identifier: HKQuantityTypeIdentifier.distanceCycling.rawValue, unit: "m", value: 10, start: start, end: start.addingTimeInterval(1))
        XCTAssertNotEqual(try a.sample().uuid, try b.sample().uuid)
    }
}
