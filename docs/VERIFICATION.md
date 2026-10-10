# Verification record

Executed locally on October 10, 2026 with Xcode 27.0 (27A266a), Swift 6.4, and the watchOS 27.0 SDK/runtime. The deployment target is watchOS 11; older runtimes have not been exercised.

## App Store preparation

The release now has a `BikeTrackStore` watch-only distribution container and a consistent `1.0.0 (1)` version across both bundles. The store identifiers are `com.youssefchouay.biketrack` and `com.youssefchouay.biketrack.watchapp`; the previous development installation uses a separate identifier.

Release preparation checks on October 10, 2026:

- Core package: all 36 tests passed.
- Demo pause/resume/end/return-home UI test: passed in `build-release-tests/ReleaseUI.xcresult`.
- Live charts, saved analysis, and bundled privacy-policy navigation: both tests passed in `build-release-tests/StoreScreens.xcresult`, with no skips or runtime warnings.
- Final unsigned store archive: passed in `build-release/BikeTrack-unsigned.xcarchive`; the archive contains one iOS watch-only container and its embedded Watch app, matching version/build values, the privacy manifest, and the offline policy.
- Five store screenshots were exported from successful simulator tests, visually checked, and verified as opaque 416 × 496 PNGs. Values in the workout screenshots are simulated demo data.
- Public privacy and support pages returned HTTP 200 after GitHub Pages deployment.

The unsigned archive is not a signed, uploadable release. Automatic signing/export currently fails because Xcode reports “No Accounts”; the account must be authenticated and appropriate development/distribution provisioning must be generated. No App Store upload or submission is established by these checks.

## Reference layout and physical installation

The reference-inspired analysis now includes zone-colored lines and area fills, an average-zone label, threshold bands with a value marker, and a compact duration/bar/percentage table. The exact zone ranges expand on demand.

The two focused 40 mm simulator UI tests passed: both live charts through saved analysis, and demo pause/resume/end/return home (`build-reference/ReferenceUIFixed.xcresult`). After the final chart-gradient optimization, the chart flow passed again with assertions for the threshold scale and expanded range labels (`build-reference/FinalReference.xcresult`). Final screenshots were captured in a successful repeat of that flow (`build-reference/ReferenceScreens.xcresult`); the updated `*-small.png` chart/zone captures show the reference layout with synthetic demo values. The final unsigned device Release build also passed.

BikeTrack 1.0 (1), bundle `com.biketrack.watchapp`, was then signed, installed, and launched on a physical **Apple Watch Series 11 running watchOS 27.2**. Xcode reported the app running on the Watch, and `devicectl` confirmed the installation. The embedded development profile includes HealthKit and the connected Watch. Initial signing was blocked by a pending Apple Developer Program License Agreement; installation succeeded after the account holder accepted it and Xcode refreshed provisioning.

This physical check establishes installation and launch only. A real equipment-connected workout, optical heart-rate recording, background operation, and Fitness synchronization remain to be validated below.

## Training zones and design refresh

The current BikeTrack bundle (`com.biketrack.watchapp`) was verified on watchOS 27 simulators:

| Check | Result |
| --- | --- |
| Core package | 36 tests passed |
| Watch-hosted recording and HealthKit tests, 46 mm | 5 passed, none skipped |
| Watch UI tests, 46 mm | 5 passed |
| Demo, charts, and settings UI tests, 40 mm | 4 passed |
| watchOS Release build | Passed with device signing disabled |

New tests cover both zone scales at exact boundaries, stale and delayed readings, pause/disconnect/recovery gaps, time-weighted averages, bounded chart storage over 20,000 observations, and decoding older records. Hosted tests verify both demo timelines freeze on pause and that equipment power analytics survive a real simulator Health save and local history persistence. UI tests open both live chart pages and saved analysis, and save/clear a training threshold.

Bundles: `build-zones/HealthAuthorization.xcresult`, `build-zones/ZoneVerification.xcresult`, and `build-zones-small/ZoneUI.xcresult`. These are local build artifacts and are excluded from Git. Screenshots named `live-zones-*`, `heart-rate-*`, `power-trend-*`, and `zone-settings-*` are actual simulator captures; workout figures shown in demo screens are synthetic.

The final recording-timer change was rechecked with all five hosted tests and the complete live-chart-to-summary UI flow in `build-zones/FinalCharts.xcresult`. The ride cards were aligned and fitted on the 40 mm display. The final compact live-chart layout passed the same flow in `build-zones-small/FinalCharts.xcresult`, and the device Release build passed again afterward. Live charts use a shorter plot and compact heading; their detailed distributions remain scrollable.

## Earlier baseline verification

The project was previously moved to its own `BikeTrack` directory and renamed from RidePulse to BikeTrack. The older result bundles below retain the original app name. The renamed app installs separately from an existing RidePulse build. Existing RidePulse workout history remains with that installation.

Immediately after the move, all 29 core tests passed from the new directory. A fresh simulator build also passed three HealthKit sample tests and the demo pause/resume/finish UI test under the BikeTrack scheme, recorded in `build-biketrack/RenameVerification.xcresult`. The full Health permission/save flow has since been repeated for BikeTrack in the training-zone verification above.

## Passed

| Check | Result |
| --- | --- |
| Core Swift package | 29 tests passed |
| Watch-hosted HealthKit tests, 46 mm simulator | 4 tests passed, none skipped |
| Watch UI tests, 46 mm simulator | 3 tests passed |
| Demo UI tests, 40 mm simulator | 2 tests passed |
| watchOS Release build for a physical device | Built successfully with signing disabled |

The core tests cover FTMS optional fields (all 8,192 defined flag combinations for each bike and treadmill layout), truncated packets, CPS/CSC revolution counters, rollover, stale readings, source priority, counter resets, reconnects, pause boundaries, sample timing, and unit formatting.

The HealthKit integration test feeds generated standard FTMS notifications through the app's workout controller. It records 200 W and 90 rpm, pauses, supplies 500 metres of paused movement, resumes, and saves. A query against the simulator's actual Health store confirms exactly one workout with 20 metres of active distance and 90 rpm average cadence. The saved summary reports 200 W average power. Other hosted tests verify compatible Health units and stable sample identities after disk round trips.

The permission/lifecycle UI test accepts the watchOS 27 Health authorization screens, starts a real workout session without equipment, and saves it. Demo tests exercise pause, resume, end, summary, return home, and discard. Demo mode does not write to Health or history.

Screenshots in this directory are exported from XCTest attachments on actual Watch simulators. Demo metric values are simulated. After visual inspection, the home title was fitted to one line and the workout icon was inset from the small display's rounded corner; the demo flow was rechecked on both display sizes.

Local result bundles (ignored by version control):

- `build/FinalVerification.xcresult`: four HealthKit tests and three UI tests.
- `build/HealthPermissionFinal.xcresult`: initial permission/start/save test.
- `build-small/FinalUI.xcresult`: two 40 mm demo tests.
- `build/FinalScreens.xcresult` and `build-small/FinalScreens.xcresult`: final layout and demo-flow checks.

## Still requires physical hardware

No Bowflex IC SE, Bowflex C6, or Schwinn IC4 was connected during development. Their Bluetooth advertisements, firmware-specific payloads, available metrics, and reconnect behavior remain unverified. Standard protocol parsing and simulator tests cannot establish model compatibility.

Optical heart rate, real active-energy estimates, wrist-down/background operation, battery consumption, connection loss, crash recovery, and phone Fitness synchronization require an on-wrist session. The signed physical installation above is ready for these checks; simulator results do not establish their outcome.

Use [HARDWARE-VALIDATION.md](HARDWARE-VALIDATION.md) for those checks. This record establishes the tested scope; it is not a claim of perfect operation on untested equipment.
