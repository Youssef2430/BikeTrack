import SwiftUI
import WatchKit

@main
struct BikeTrackApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var workout = WorkoutController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workout)
                .environmentObject(workout.bluetooth)
                .tint(Palette.lime)
                .task {
                    if ProcessInfo.processInfo.arguments.contains("--demo") {
                        await workout.start(activity: .cycling, demo: true)
                    } else if workout.recoveryRecord != nil {
                        await workout.recover()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { workout.checkpoint() }
                }
        }
    }
}

final class AppDelegate: NSObject, WKApplicationDelegate {
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in await WorkoutController.shared.recover() }
    }
}
