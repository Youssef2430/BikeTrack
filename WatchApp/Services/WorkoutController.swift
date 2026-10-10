import Foundation
@preconcurrency import HealthKit
import WatchKit
import RideCore

enum WorkoutPhase: Equatable {
    case idle, preparing, running, paused, ending, saving, saveFailed, summary
}

struct SampleDraft: Codable {
    var id = UUID()
    var identifier: String
    var unit: String
    var value: Double
    var start: Date
    var end: Date
    private var archive: Data

    init(identifier: String, unit: String, value: Double, start: Date, end: Date) throws {
        self.identifier = identifier; self.unit = unit; self.value = value
        self.start = start; self.end = end
        let sample = HKQuantitySample(type: HKQuantityType(HKQuantityTypeIdentifier(rawValue: identifier)),
                         quantity: HKQuantity(unit: HKUnit(from: unit), doubleValue: value),
                         start: start, end: end,
                         metadata: [HKMetadataKeySyncIdentifier: "biketrack.\(id.uuidString)", HKMetadataKeySyncVersion: 1])
        archive = try NSKeyedArchiver.archivedData(withRootObject: sample, requiringSecureCoding: true)
    }

    func sample() throws -> HKQuantitySample {
        guard let sample = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQuantitySample.self, from: archive) else {
            throw WorkoutError("A queued Health sample could not be restored.")
        }
        return sample
    }
}

private struct WorkoutCheckpoint: Codable {
    var record: WorkoutRecord
    var pending: [SampleDraft]
}

@MainActor
final class WorkoutController: NSObject, ObservableObject {
    static let shared = WorkoutController()
    @Published private(set) var phase: WorkoutPhase = .idle
    @Published private(set) var engine = MetricsEngine()
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var heartRate: Double?
    @Published private(set) var energyKcal: Double?
    @Published private(set) var activity: ActivityKind = .cycling
    @Published private(set) var isDemo = false
    @Published private(set) var summary: WorkoutRecord?
    @Published private(set) var recoveryRecord: WorkoutRecord?
    @Published var errorMessage: String?
    @Published private(set) var healthNotice: String?
    let bluetooth = BluetoothManager()

    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var recordID = UUID()
    private var startedAt = Date()
    private var segmentStart = Date()
    private var demoElapsed: TimeInterval = 0
    private var demoTick = 0
    private var demoCounter: Double = 0
    private var pending: [SampleDraft] = []
    private var lastSampleDates: [String: Date] = [:]
    private var flushTask: Task<Void, Error>?
    private var collectionEnded = false
    private var finishing = false
    private var lastCheckpoint = Date.distantPast
    private var latestHeartRateDate: Date?
    private var recovered = false
    private var endingDate: Date?
    private var attemptedFinish = false

    private let externalTypes: [HKQuantityTypeIdentifier] = [
        .distanceCycling, .distanceWalkingRunning, .cyclingPower, .cyclingCadence, .cyclingSpeed, .runningSpeed
    ]

    override init() {
        super.init()
        bluetooth.onPacket = { [weak self] packet, source, date in self?.receive(packet, source: source, at: date) }
        bluetooth.onDisconnect = { [weak self] in self?.engine.disconnect() }
        do {
            if let data = try LocalStore.shared.read("active-workout.json") {
                let checkpoint = try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
                recoveryRecord = checkpoint.record
            }
        } catch { LocalStore.shared.report(error) }
    }

    var canStart: Bool { phase == .idle && recoveryRecord == nil }

    func start(activity: ActivityKind, demo: Bool = false) async {
        guard canStart else { return }
        phase = .preparing
        self.activity = activity
        isDemo = demo
        errorMessage = nil; healthNotice = nil
        heartRate = nil; energyKcal = nil; summary = nil
        elapsed = 0; demoElapsed = 0; demoTick = 0; demoCounter = 0
        pending.removeAll(); lastSampleDates.removeAll()
        collectionEnded = false; finishing = false; endingDate = nil; recovered = false
        attemptedFinish = false
        recordID = UUID()
        engine = MetricsEngine()
        if UserDefaults.standard.bool(forKey: "wheelDistance") {
            let millimeters = UserDefaults.standard.double(forKey: "wheelMM")
            engine.wheelCircumferenceMeters = (millimeters > 0 ? millimeters : 2105) / 1000
        }
        if demo {
            bluetooth.disconnect()
            startedAt = Date(); segmentStart = startedAt
            engine.begin()
            phase = .running
            startTimer()
            return
        }
        do {
            guard HKHealthStore.isHealthDataAvailable() else { throw WorkoutError("Apple Health is unavailable on this device.") }
            let quantities = Set((externalTypes + [.heartRate, .activeEnergyBurned]).map { HKQuantityType($0) })
            var write: Set<HKSampleType> = Set(quantities)
            write.insert(HKObjectType.workoutType())
            var read: Set<HKObjectType> = Set(quantities)
            read.insert(HKObjectType.workoutType())
            try await health.requestAuthorization(toShare: write, read: read)
            guard health.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                throw WorkoutError("Allow BikeTrack to save Workouts in Health permissions, then try again.")
            }
            let missing = quantities.filter { health.authorizationStatus(for: $0) != .sharingAuthorized }
            if !missing.isEmpty { healthNotice = "Some Health metrics are disabled. Enable all requested permissions to save every metric." }
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activity.healthType
            configuration.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: health, configuration: configuration)
            self.session = session
            attach(session)
            startedAt = Date(); segmentStart = startedAt
            session.startActivity(with: startedAt)
            try await builder!.beginCollection(at: startedAt)
            try await builder!.addMetadata([
                HKMetadataKeyIndoorWorkout: true,
                HKMetadataKeySyncIdentifier: "biketrack.workout.\(recordID.uuidString)",
                HKMetadataKeySyncVersion: 1
            ])
            engine.begin()
            phase = .running
            checkpoint()
            startTimer()
            WKInterfaceDevice.current().play(.start)
        } catch {
            session?.end()
            builder?.discardWorkout()
            session = nil; builder = nil
            phase = .idle
            errorMessage = error.localizedDescription
        }
    }

    private func attach(_ session: HKWorkoutSession) {
        session.delegate = self
        let builder = session.associatedWorkoutBuilder()
        self.builder = builder
        builder.delegate = self
        let source = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: session.workoutConfiguration)
        // The equipment owns distance/power/cadence. Disable automatic sources
        // so HealthKit cannot add a second estimate of the same distance.
        for identifier in externalTypes { source.disableCollection(for: HKQuantityType(identifier)) }
        builder.dataSource = source
    }

    func pauseOrResume() {
        guard phase == .running || phase == .paused else { return }
        let resume = phase == .paused
        if isDemo {
            if !resume { demoElapsed = elapsed }
            segmentStart = Date()
            phase = resume ? .running : .paused
            engine.setActive(resume)
        } else {
            // Close the sampling gate immediately; HealthKit's delegate confirms
            // the actual event time before samples can resume.
            engine.setActive(false)
            if resume { session?.resume() } else { session?.pause() }
        }
        WKInterfaceDevice.current().play(resume ? .start : .stop)
    }

    func endAndSave() {
        guard phase == .running || phase == .paused else { return }
        endingDate = Date()
        if isDemo {
            if phase == .running { elapsed = demoElapsed + Date().timeIntervalSince(segmentStart) }
            engine.setActive(false)
            timer?.invalidate()
            summary = makeRecord()
            phase = .summary
            return
        }
        phase = .ending
        engine.setActive(false)
        checkpoint()
        session?.stopActivity(with: endingDate)
    }

    func retrySave() {
        guard phase == .saveFailed, builder != nil, !finishing else { return }
        Task { await finish() }
    }

    private func finish() async {
        guard !finishing, let builder else { return }
        finishing = true
        defer { finishing = false }
        phase = .saving
        do {
            if attemptedFinish, let saved = try await savedWorkout(id: recordID) {
                confirmSaved(saved, record: makeRecord())
                return
            }
            if let flushTask { try await flushTask.value }
            try await flush()
            if !collectionEnded {
                try await builder.endCollection(at: endingDate ?? Date())
                collectionEnded = true
            }
            attemptedFinish = true
            guard let workout = try await builder.finishWorkout() else { throw WorkoutError("Health did not confirm the saved workout. Please retry.") }
            confirmSaved(workout, record: makeRecord())
        } catch {
            phase = .saveFailed
            errorMessage = "Your workout has not been confirmed saved. \(error.localizedDescription)"
            checkpoint()
        }
    }

    private func savedWorkout(id: UUID) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                                       allowedValues: ["biketrack.workout.\(id.uuidString)"])
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: results?.first as? HKWorkout) }
            }
            health.execute(query)
        }
    }

    private func confirmSaved(_ workout: HKWorkout, record original: WorkoutRecord) {
        var record = original
        record.duration = workout.duration
        record.savedToHealth = true
        record.averagePower = workout.statistics(for: HKQuantityType(.cyclingPower))?.averageQuantity()?.doubleValue(for: .watt())
        record.averageHeartRate = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        record.energyKcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        summary = record
        LocalStore.shared.save(record)
        LocalStore.shared.remove("active-workout.json")
        recoveryRecord = nil
        session?.end()
        timer?.invalidate()
        phase = .summary
        errorMessage = nil
        WKInterfaceDevice.current().play(.success)
    }

    func discard() async {
        guard phase != .saving && phase != .ending && phase != .preparing else { return }
        engine.setActive(false)
        timer?.invalidate()
        if let flushTask { _ = try? await flushTask.value }
        builder?.discardWorkout()
        session?.end()
        LocalStore.shared.remove("active-workout.json")
        recoveryRecord = nil
        reset()
    }

    func reset() {
        timer?.invalidate()
        session = nil; builder = nil
        pending.removeAll(); lastSampleDates.removeAll()
        engine = MetricsEngine()
        summary = nil; errorMessage = nil; heartRate = nil; energyKcal = nil
        elapsed = 0; isDemo = false; phase = .idle
    }

    func dismissRecovery() {
        // Only called after the user explicitly discards an unrecoverable local
        // checkpoint. Existing Health workouts are never deleted here.
        LocalStore.shared.remove("active-workout.json")
        recoveryRecord = nil
    }

    func retryRecovery() async {
        recovered = false
        await recover()
    }

    func recover() async {
        guard phase == .idle, !recovered else { return }
        recovered = true
        phase = .preparing
        do {
            guard let session = try await health.recoverActiveWorkoutSession() else {
                phase = .idle
                if let recoveryRecord, let saved = try await savedWorkout(id: recoveryRecord.id) {
                    confirmSaved(saved, record: recoveryRecord)
                } else if recoveryRecord != nil {
                    errorMessage = "The previous workout could not be resumed. Its last local summary is retained. Check Fitness for a saved workout before discarding it."
                }
                return
            }
            self.session = session
            attach(session)
            startedAt = session.startDate ?? Date()
            segmentStart = Date()
            activity = ActivityKind(healthType: session.workoutConfiguration.activityType)
            var restoredRecord: WorkoutRecord?
            if let data = try LocalStore.shared.read("active-workout.json") {
                let checkpoint = try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
                if abs(checkpoint.record.startedAt.timeIntervalSince(startedAt)) < 2 {
                    recordID = checkpoint.record.id
                    pending = checkpoint.pending
                    restoredRecord = checkpoint.record
                }
            }
            let type = HKQuantityType(activity == .cycling ? .distanceCycling : .distanceWalkingRunning)
            let distance = builder?.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            // The checkpoint already includes queued samples. Adding those to
            // builder statistics would double count a batch committed just
            // before a crash. Use the larger durable total instead.
            engine.begin(restoringDistance: max(distance, restoredRecord?.distanceMeters ?? 0),
                         restoringMethod: restoredRecord?.distanceMethod ?? .unavailable)
            recoveryRecord = nil
            isDemo = false
            switch session.state {
            case .running: phase = .running
            case .paused: phase = .paused; engine.setActive(false)
            case .stopped, .ended:
                phase = .saveFailed; engine.setActive(false)
                endingDate = session.endDate ?? Date()
            default: throw WorkoutError("The previous workout is no longer active.")
            }
            bluetooth.reconnectSaved()
            startTimer()
            checkpoint()
        } catch {
            phase = .idle
            errorMessage = "Recovery failed: \(error.localizedDescription)"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        if isDemo, phase == .running {
            elapsed = demoElapsed + now.timeIntervalSince(segmentStart)
            demoTick += 1
            let speed = activity == .cycling ? 28 + sin(Double(demoTick) / 8) * 3 : 9 + sin(Double(demoTick) / 8)
            demoCounter += speed / 3.6
            let packet = BikePacket(speedKPH: speed,
                                    cadenceRPM: activity == .cycling ? 84 + sin(Double(demoTick) / 4) * 5 : nil,
                                    powerWatts: activity == .cycling ? 180 + sin(Double(demoTick) / 7) * 30 : nil,
                                    distanceMeters: demoCounter)
            receive(packet, source: activity == .cycling ? .indoorBike : .treadmill, at: now)
            heartRate = 136 + sin(Double(demoTick) / 9) * 8
            energyKcal = elapsed / 10
        } else if let builder {
            elapsed = builder.elapsedTime(at: now)
            if let date = latestHeartRateDate, now.timeIntervalSince(date) > 20 { heartRate = nil }
            if now.timeIntervalSince(lastCheckpoint) >= 5, phase == .running || phase == .paused {
                checkpoint()
                startFlush()
            }
        }
    }

    private func receive(_ packet: BikePacket, source: PacketSource, at date: Date) {
        guard phase == .running || phase == .paused else { return }
        guard (activity == .cycling && source != .treadmill) || (activity != .cycling && source == .treadmill) else { return }
        let update = engine.ingest(packet, source: source, at: date)
        guard phase == .running, engine.active, !isDemo else { return }
        if activity == .cycling {
            enqueue(.cyclingPower, unit: "W", value: update.power, at: date)
            enqueue(.cyclingCadence, unit: "count/min", value: update.cadence, at: date)
            enqueue(.cyclingSpeed, unit: "m/s", value: update.speed.map { $0 / 3.6 }, at: date)
        } else if activity == .running {
            enqueue(.runningSpeed, unit: "m/s", value: update.speed.map { $0 / 3.6 }, at: date)
        }
        if update.distanceDelta > 0 {
            enqueue(activity == .cycling ? .distanceCycling : .distanceWalkingRunning,
                    unit: "m", value: update.distanceDelta, at: date, cumulative: true)
        }
    }

    private func enqueue(_ identifier: HKQuantityTypeIdentifier, unit: String, value: Double?, at date: Date, cumulative: Bool = false) {
        guard let value, value.isFinite, value >= 0,
              health.authorizationStatus(for: HKQuantityType(identifier)) == .sharingAuthorized else { return }
        guard let interval = SampleTiming.interval(previous: lastSampleDates[identifier.rawValue],
                                                   segmentStart: segmentStart, end: date, cumulative: cumulative) else { return }
        do {
            pending.append(try SampleDraft(identifier: identifier.rawValue, unit: unit, value: value, start: interval.start, end: interval.end))
        } catch {
            healthNotice = "A sensor sample could not be queued: \(error.localizedDescription)"
            return
        }
        lastSampleDates[identifier.rawValue] = date
    }

    private func startFlush() {
        guard flushTask == nil, !pending.isEmpty else { return }
        flushTask = Task { [weak self] in
            guard let self else { return }
            defer { self.flushTask = nil }
            do { try await self.flush() }
            catch {
                self.healthNotice = "Health recording is delayed. Samples are kept locally for retry."
                DiagnosticLog.shared.add("Health sample batch failed; retaining for retry")
                throw error
            }
        }
    }

    private func flush() async throws {
        guard let builder else { return }
        // Snapshot each batch while allowing new notifications to keep queuing.
        while !pending.isEmpty {
            let batch = Array(pending.prefix(200))
            try LocalStore.shared.write(WorkoutCheckpoint(record: makeRecord(), pending: pending), to: "active-workout.json")
            // Preserve the original HKObject UUID as well as its sync ID across
            // retries and process recovery; never recreate a committed sample.
            let samples = try batch.map { try $0.sample() }
            try await builder.addSamples(samples)
            let ids = Set(batch.map(\.id))
            pending.removeAll { ids.contains($0.id) }
            checkpoint()
        }
    }

    func checkpoint() {
        // The system permission sheet can background the app before a session
        // exists. Never turn an authorization request into a phantom recovery.
        guard !isDemo, builder != nil, phase != .idle, phase != .summary, phase != .preparing else { return }
        do {
            try LocalStore.shared.write(WorkoutCheckpoint(record: makeRecord(), pending: pending), to: "active-workout.json")
            lastCheckpoint = Date()
        } catch { LocalStore.shared.report(error) }
    }

    private func makeRecord() -> WorkoutRecord {
        WorkoutRecord(id: recordID, startedAt: startedAt, activity: activity, duration: elapsed,
                      distanceMeters: engine.distanceMeters, distanceMethod: engine.distanceMethod,
                      averagePower: builder?.statistics(for: HKQuantityType(.cyclingPower))?.averageQuantity()?.doubleValue(for: .watt()),
                      averageHeartRate: builder?.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                      energyKcal: energyKcal, isDemo: isDemo)
    }
}

extension WorkoutController: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            switch toState {
            case .running:
                if self.phase == .paused {
                    self.segmentStart = date
                    self.engine.setActive(true)
                    self.phase = .running
                }
            case .paused:
                if self.phase == .running {
                    self.engine.setActive(false)
                    self.phase = .paused
                }
            case .stopped:
                if self.phase == .ending { await self.finish() }
            case .ended:
                if self.phase == .running || self.phase == .paused {
                    self.engine.setActive(false)
                    self.endingDate = date
                    await self.finish()
                }
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            self.errorMessage = "Workout interrupted: \(error.localizedDescription)"
            if self.phase == .running || self.phase == .paused {
                self.engine.setActive(false)
                self.endingDate = Date()
                await self.finish()
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor [weak self] in
            guard let self, self.builder === workoutBuilder else { return }
            for type in collectedTypes {
                guard let quantity = type as? HKQuantityType, let stats = workoutBuilder.statistics(for: quantity) else { continue }
                if quantity.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                    self.heartRate = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.latestHeartRateDate = stats.mostRecentQuantityDateInterval()?.end
                } else if quantity.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue {
                    self.energyKcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
                }
            }
        }
    }
}

private struct WorkoutError: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

extension ActivityKind {
    var healthType: HKWorkoutActivityType {
        switch self { case .cycling: .cycling; case .running: .running; case .walking: .walking }
    }
    init(healthType: HKWorkoutActivityType) {
        switch healthType { case .running: self = .running; case .walking: self = .walking; default: self = .cycling }
    }
}
