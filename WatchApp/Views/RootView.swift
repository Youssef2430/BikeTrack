import SwiftUI
import RideCore

enum Palette {
    static let lime = Color(red: 0.77, green: 0.98, blue: 0.32)
    static let coral = Color(red: 1, green: 0.66, blue: 0.51)
    static let blue = Color(red: 0.65, green: 0.75, blue: 1)
    static let panel = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let muted = Color(red: 0.66, green: 0.69, blue: 0.73)

    static func zone(_ id: Int) -> Color {
        [blue, Color(red: 0.99, green: 0.88, blue: 0.65), Color(red: 1, green: 0.81, blue: 0.50),
         coral, Color(red: 1, green: 0.46, blue: 0.28), Color(red: 0.96, green: 0.35, blue: 0.39),
         Color(red: 0.84, green: 0.55, blue: 0.88), Color(red: 0.70, green: 0.61, blue: 1)][min(7, max(0, id))]
    }
}

struct RootView: View {
    @EnvironmentObject private var workout: WorkoutController

    var body: some View {
        Group {
            switch workout.phase {
            case .idle: NavigationStack { HomeView() }
            case .preparing: ProgressView("Getting ready…")
            case .running, .paused: WorkoutView()
            case .ending, .saving: ProgressView("Saving workout…")
            case .saveFailed: SaveFailureView()
            case .summary:
                if let summary = workout.summary { NavigationStack { SummaryView(record: summary, dismiss: workout.reset) } }
            }
        }
        .background(Color.black)
        .alert("BikeTrack", isPresented: Binding(
            get: { workout.errorMessage != nil && workout.phase != .saveFailed },
            set: { if !$0 { workout.errorMessage = nil } }
        )) {
            Button("OK") { workout.errorMessage = nil }
        } message: { Text(workout.errorMessage ?? "") }
    }
}

struct HomeView: View {
    @EnvironmentObject private var workout: WorkoutController
    @EnvironmentObject private var bluetooth: BluetoothManager
    @State private var activity: ActivityKind = .cycling
    @State private var confirmRecoveryDiscard = false

    private var equipmentMatches: Bool {
        if activity == .cycling { return !bluetooth.availableSources.subtracting([.treadmill]).isEmpty }
        return bluetooth.availableSources.contains(.treadmill)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let recovery = workout.recoveryRecord {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unfinished workout", systemImage: "exclamationmark.arrow.circlepath")
                            .font(.headline).foregroundStyle(Palette.lime)
                        Text("\(MetricFormat.elapsed(recovery.duration)) recorded locally. Check Fitness before discarding.")
                            .font(.footnote)
                        Button("Try recovery again") { Task { await workout.retryRecovery() } }
                        Button("Discard local recovery", role: .destructive) { confirmRecoveryDiscard = true }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: activity.symbol)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Palette.lime)
                            .frame(width: 46, height: 46)
                            .background(Palette.lime.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity == .cycling ? "Just ride." : "Let's move.")
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(activity.title).font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    NavigationLink {
                        EquipmentView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: bluetooth.connected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                                .foregroundStyle(bluetooth.connected ? Palette.lime : Palette.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bluetooth.selectedName ?? "Connect equipment").font(.system(size: 13, weight: .semibold))
                                Text(bluetooth.connected ? "Ready to go" : "Bike or treadmill")
                                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                        }.padding(.vertical, 3)
                    }.accessibilityIdentifier("connectEquipment")
                    Button {
                        Task { await workout.start(activity: activity) }
                    } label: {
                        Label(activity == .cycling ? "Start ride" : "Start workout", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.lime).foregroundStyle(.black)
                    .disabled(!bluetooth.connected || !equipmentMatches)
                    .accessibilityIdentifier("startWorkout")
                    if bluetooth.connected && !equipmentMatches {
                        Text("Choose a workout that matches your connected equipment.").font(.caption2).foregroundStyle(Palette.muted)
                    }
                    Picker("Workout", selection: $activity) {
                        ForEach(ActivityKind.allCases) { kind in Text(kind.title).tag(kind) }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("activityPicker")
                    Button("Record without equipment") { Task { await workout.start(activity: activity) } }
                        .font(.caption2).buttonStyle(.plain).foregroundStyle(Palette.muted)
                }
                HStack {
                    NavigationLink { HistoryView() } label: { Image(systemName: "clock.arrow.circlepath") }
                        .accessibilityLabel("Workout history")
                    NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settings")
                }
                NavigationLink { ZoneSettingsView() } label: {
                    Label("Training zones", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .medium))
                }.accessibilityIdentifier("trainingZones")
                Button("Try demo ride") { Task { await workout.start(activity: activity, demo: true) } }
                    .font(.caption2).foregroundStyle(Palette.muted).buttonStyle(.plain)
                    .disabled(!workout.canStart)
                    .accessibilityIdentifier("demoRide")
            }.padding(.horizontal, 2).padding(.bottom, 10)
        }
        .navigationTitle("BikeTrack")
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog("Discard the unfinished local workout?", isPresented: $confirmRecoveryDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { workout.dismissRecovery() }
        }
    }
}

struct EquipmentView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    var body: some View {
        List {
            Section {
                Text(bluetooth.status).font(.footnote).foregroundStyle(bluetooth.connected ? Palette.lime : Palette.muted)
                if bluetooth.connected || bluetooth.selectedName != nil {
                    Text(bluetooth.selectedName ?? "Equipment").font(.headline)
                    Button("Disconnect", role: .destructive) { bluetooth.disconnect(); bluetooth.scan() }
                } else {
                    ForEach(bluetooth.devices) { device in
                        Button { bluetooth.connect(device.id) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name).font(.headline)
                                Text(device.rssi > -65 ? "Strong signal" : "Move closer for a stronger signal")
                                    .font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    if bluetooth.scanning { ProgressView().frame(maxWidth: .infinity) }
                    else { Button("Scan again") { bluetooth.scan() } }
                }
            }
            Section {
                Text("Wake your bike by pedaling. Disconnect other apps if your equipment allows only one Bluetooth connection.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .navigationTitle("Equipment")
        .onAppear { if !bluetooth.connected && bluetooth.selectedName == nil { bluetooth.scan() } }
        .onDisappear { bluetooth.stopScan() }
    }
}
