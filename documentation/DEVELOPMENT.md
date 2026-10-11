# Development

Open `BikeTrack.xcodeproj` in Xcode and choose the **BikeTrack** scheme with a watchOS simulator. The app requires watchOS 11 or later. The project is generated from `project.yml`; run `xcodegen generate` after changing that file.

## Repository layout

- `WatchApp/`: SwiftUI app, services, and bundled resources.
- `Sources/RideCore/`: platform-independent Bluetooth parsing and workout analytics.
- `Tests/`: core package, Watch-hosted, and UI tests.
- `assets/`: brand artwork and simulator screenshots with demo data.
- `documentation/`: implementation, training-zone methodology, and hardware checks.
- `website/src/`: public website source; `docs/` is the generated GitHub Pages site.
- `Configuration/`: shareable configuration examples.
- `tools/`: asset-generation scripts.

## Build and test

```sh
swift test
xcodebuild -project BikeTrack.xcodeproj -scheme BikeTrack \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

List available simulators with `xcrun simctl list devices available`. For Watch-hosted and UI tests, use an available Watch simulator ID:

```sh
xcodebuild -project BikeTrack.xcodeproj -scheme BikeTrack \
  -destination 'platform=watchOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath build -parallel-testing-enabled NO \
  -only-testing:BikeTrackUITests/BikeTrackUITests/testHealthWorkoutLifecycleInSimulator \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test
xcodebuild -project BikeTrack.xcodeproj -scheme BikeTrack \
  -destination 'platform=watchOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath build -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test
```

The first command handles Health permissions on a fresh simulator. Ad-hoc signing preserves the HealthKit entitlement. Health integration tests use the simulator's isolated Health store and are disabled on physical Watches. Permission-sheet automation was verified on watchOS 27.

To install on your Watch, select your own development team in Xcode and use unique bundle identifiers if needed. Keep HealthKit enabled. Signing changes are local; do not commit your team or provisioning settings.

## Distribution

Use **BikeTrackStore** for watch-only App Store archives. Copy `Configuration/ExportOptions.example.plist` to `.local/ExportOptions.plist`, then fill in your team ID. Pass your team as `DEVELOPMENT_TEAM=YOUR_TEAM_ID` when archiving from the command line. Signed distribution requires your own Apple Developer account and provisioning.

Keep credentials, signing material, App Review contacts, submission records, and exported archives out of Git. `.local/` is ignored for private working files.

## More information

- [Implementation](IMPLEMENTATION.md)
- [Training zones](TRAINING-ZONES.md)
- [Verification scope](VERIFICATION.md)
- [Physical hardware checks](HARDWARE-VALIDATION.md)
- [Website development](../website/README.md)
- [Icon generation and attribution](../assets/brand/README.md)
