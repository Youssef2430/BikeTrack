# Verification scope

The app was verified on October 10–11, 2026 with Xcode 27.0, Swift 6.4, and watchOS 27 simulators. The deployment target is watchOS 11; older runtimes have not been exercised.

- All 36 core package tests passed, covering Bluetooth packet layouts, truncated data, counters, reconnects, distance accounting, training zones, and workout analytics.
- Watch-hosted tests exercised HealthKit sample persistence, generated equipment readings, and demo isolation.
- UI tests exercised permissions, workout lifecycle, live charts, saved analysis, settings, and the bundled privacy policy on small and large Watch simulators.
- Simulator and unsigned device builds passed. A signed build was installed and launched on a physical Apple Watch.
- Store screenshots are actual simulator captures showing simulated demo workouts. They are stored in `assets/screenshots/app-store/`; additional captures are in `assets/screenshots/watch/`.

These results establish the tested scope, not hardware compatibility. No Bowflex IC SE, Bowflex C6, or Schwinn IC4 was connected during development. Real equipment measurements, optical heart rate, background recording, battery use, reconnection, recovery, and Fitness synchronization still require on-wrist validation.

See [development instructions](DEVELOPMENT.md) to repeat automated checks and [hardware validation](HARDWARE-VALIDATION.md) for the outstanding physical checks. Build results and private release records are kept outside version control.
