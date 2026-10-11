# Physical-device acceptance checks

Run this on each intended bike: Bowflex IC SE, Bowflex C6, and Schwinn IC4. Record the Watch model, watchOS version, bike firmware, and observed Bluetooth services. These checks require the actual hardware and have not been completed in the development environment.

1. **Discovery and first connection:** Wake the bike. It appears in the list, connects, and starts publishing its supported metrics. Denied Bluetooth permission and Bluetooth-off states show useful instructions.
2. **Metric accuracy:** At several steady cadences and resistance levels, compare watts, cadence, speed, and distance with the bike's display. Confirm units and whether the bike actually broadcasts every metric. The app must not invent unavailable distance or power.
3. **Heart rate:** Start a workout with all Health permissions granted. Compare the displayed Watch heart rate with the Watch's expected reading. Denying heart-rate access leaves a dash and does not display bike contact-sensor heart rate as if it came from the Watch.
4. **Wrist-down recording:** Ride at least 20 minutes, including five minutes with the wrist lowered and time in another Watch app. Check for missing samples, termination, or unreasonable battery/CPU use.
5. **Disconnect and reconnect:** Break the bike connection for 30 seconds while continuing to ride. Reconnect automatically. Distance must never reset or jump by the bike's full cumulative total. A cumulative counter can recover the gap; speed-only distance must not extrapolate it.
6. **Bike reset:** Restart the bike or reset its session counter mid-workout. The app rebases the new counter while retaining distance already recorded.
7. **Pause/resume:** Pause for one minute while still pedaling, including a Bluetooth disconnect during the pause. Resume. Paused duration and paused distance must not appear in the workout. A boundary packet may be used only as a new baseline.
8. **Save:** End and save. Verify exactly one correctly typed indoor workout in Fitness and Health, with duration, active energy, heart rate, distance, and supported cycling metrics. Review time-series samples and confirm distance is not doubled by the Watch's estimate.
9. **Limited permissions:** Deny distance or cycling-power writes. The app explains that some metrics are disabled, saves only authorized fields, and does not repeatedly attempt unauthorized writes. Denying workout writes prevents starting a real recording.
10. **Save interruption:** Exercise a failed Health write and retry. No duplicate samples or duplicate workout should appear. A failed save must never display a success state.
11. **Active recovery:** Terminate the app during a workout, let watchOS relaunch it for active-workout recovery, and verify session state, elapsed time, pending sample identities, Bluetooth reconnection, and eventual save. Force quitting and OS termination are not equivalent; record which was tested.
12. **Discard and next workout:** Discard a session. No workout summary is saved in BikeTrack. Start a new one: elapsed time and workout distance start at zero. Health samples the system already collected may remain in Health after a discarded workout.
13. **Diagnostics:** Enable capture, reconnect, and inspect/share the log. It contains connection events, characteristic IDs, flags, and packet lengths; no heart-rate values, account data, or automatic uploads.

Treadmill checks additionally verify Indoor Run versus Indoor Walk classification and that walking/running distance is used instead of cycling distance. Wheel sensors require an explicitly calibrated circumference before checking derived speed and distance.

Passing compilation and automated tests is not a substitute for these checks. No claim of perfect operation or hardware certification is made.
