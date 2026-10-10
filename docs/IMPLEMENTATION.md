# Implementation and references

## Structure

- `Sources/RideCore`: platform-independent packet parsing, revolution calculations, source selection, distance accounting, zone classification, time-weighted analytics, and record formatting. Tested on macOS with Swift Testing.
- `WatchApp/Services/BluetoothManager.swift`: main-queue CoreBluetooth discovery, subscriptions, reconnection with capped backoff, and packet routing.
- `WatchApp/Services/WorkoutController.swift`: HealthKit lifecycle, sample buffering, durable checkpoints, retry, recovery, and demo isolation.
- `WatchApp/Services/LocalStore.swift`: atomic local JSON storage and opt-in diagnostics.
- `WatchApp/Views`: native SwiftUI home, equipment, workout pages, summary, history, and settings, with Swift Charts for heart-rate and power trends.
- `WatchTests`: Watch-hosted HealthKit sample archive, unit compatibility, and equipment-to-workout persistence tests.
- `UITests`: actual Watch simulator interaction tests.
- `project.yml`: reproducible XcodeGen project definition. The `.xcodeproj` is also included.

There are no external runtime packages. `RideCore` is a local Swift package.

Training analytics are captured from accepted equipment power and HealthKit heart-rate observations, with independent freshness limits. The main-run-loop timer uses common modes so elapsed time and recording updates continue during scrolling. Each checkpoint stores the original threshold profile, bounded display samples, and independently accumulated zone totals. See [TRAINING-ZONES.md](TRAINING-ZONES.md) for exact boundaries and accounting rules.

## Bluetooth

Supported services are Fitness Machine (`1826`), Cycling Power (`1818`), and Cycling Speed & Cadence (`1816`). Measurement characteristics are Indoor Bike Data (`2AD2`), Treadmill Data (`2ACD`), Cycling Power Measurement (`2A63`), and CSC Measurement (`2A5B`).

FTMS flags determine field presence; More Data reverses the usual presence rule for instantaneous speed. Optional fields are consumed in specification order, including fields not used by the UI. Truncated or unknown-reserved-flag packets are rejected atomically. Separate FTMS notifications update only their present metrics.

Crank counters and event clocks use modular subtraction. Long/ambiguous clock gaps and physically implausible rates are rejected. CPS wheel timestamps use 2048 Hz; CSC wheel and crank timestamps use 1024 Hz. Crank stalling resolves to zero; absent/stale notifications resolve to unavailable.

Metric priority is FTMS, then Cycling Power, then CSC, with fallback after five seconds without fresh data from a higher-priority source. Standard equipment read/notify operations are used; no machine-control commands are sent.

## Distance and Health ownership

The first machine total establishes a baseline, so a pre-existing bike session does not become part of a new workout. Positive deltas are accumulated. A counter reset rebases without subtracting previously recorded distance. Active reconnection retains the counter baseline; pause/resume resets it to exclude paused movement. Speed integration only bridges consecutive updates at most five seconds apart. Machine distance takes precedence over speed integration.

HealthKit's automatic equipment-related collection is disabled to prevent double counting. Watch heart rate and active energy come from the live workout data source. Authorized equipment samples are added in batches, using incremental distance samples. Live metric values are recorded at up to roughly one sample per second per metric; distance increments are not dropped for throttling. A power, cadence, or speed sample spans at most one second, so a fresh reading cannot fill a preceding sensor dropout. Cumulative distance can cover the interval actually observed by the machine counter.

Samples carry stable sync identifiers and versions, and their original HealthKit UUIDs survive secure archive/restore. A retry reuses the same sample identities. The workout also has a stable sync identifier so an interrupted save can be checked against Health before another finish attempt. A successful summary appears only after Health confirms the workout exists.

## Recovery boundaries

An atomic checkpoint is written before each sample batch and approximately every five seconds during recording. If watchOS offers an active workout session after process termination, the app reattaches its builder, delegates, and data source, restores the checkpoint, and reconnects the last selected peripheral. An unrecoverable checkpoint remains visible for explicit user handling.

A crash before the next checkpoint can lose the most recent uncommitted equipment samples (normally up to approximately five seconds). WatchOS recovery is conditional on the system retaining the session. Speed-only distance cannot recover unobserved movement during a disconnect. The first packet after a new recording segment or recovery establishes a fresh baseline. These constraints are surfaced rather than replaced with fabricated data.

## Sources

- [Original developer feature brief](https://www.reddit.com/r/IndoorCycling/comments/1qd9zjm/i_built_a_free_apple_watch_app_to_sync_indoor/)
- [Bluetooth SIG Fitness Machine Service 1.0](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/)
- [Bluetooth SIG Cycling Power Service 1.1](https://www.bluetooth.com/specifications/specs/cycling-power-service-1-1/)
- [Bluetooth SIG Cycling Speed & Cadence Service 1.0](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/CSCS_v1.0/out/en/index-en.html)
- [Apple: Build a workout app for Apple Watch](https://developer.apple.com/documentation/healthkit/build-a-workout-app-for-apple-watch)
- [Apple: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions)
- [Apple: Recover an active workout session](https://developer.apple.com/documentation/healthkit/hkhealthstore/recoveractiveworkoutsession(completion:))
- [Apple: HealthKit sync identifiers](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier)

The reference informed the feature scope; no original application binary, source code, name, or artwork was copied.
