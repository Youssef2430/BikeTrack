import SwiftUI
import RideCore

struct RootView: View {
    @EnvironmentObject private var workout: WorkoutController

    var body: some View {
        Group {
            switch workout.phase {
            case .idle: NavigationStack { HomeView() }
            case .preparing: ProgressView("Getting ready…")
            case .running, .paused: WorkoutView()
            case .ending, .saving: ProgressView("Saving workout…")
            case .saveFailed: NavigationStack { SaveFailureView() }
            case .summary:
                if let summary = workout.summary { NavigationStack { SummaryView(record: summary, dismiss: workout.reset) } }
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
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
            VStack(spacing: 10) {
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
                        ActivityEmblem(symbol: activity.symbol, size: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity == .cycling ? "Just ride." : "Let's move.")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Eyebrow(title: activity.title)
                        }
                        Spacer(minLength: 0)
                    }.padding(.vertical, 2)
                    Button {
                        Task { await workout.start(activity: activity) }
                    } label: {
                        Label(activity == .cycling ? "Start ride" : "Start workout", systemImage: "play.fill")
                    }
                    .buttonStyle(RideButtonStyle(prominent: true))
                    .disabled(!bluetooth.connected || !equipmentMatches)
                    .accessibilityIdentifier("startWorkout")
                    NavigationLink {
                        EquipmentView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: bluetooth.connected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                                .foregroundStyle(Palette.lime)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bluetooth.selectedName ?? "Connect")
                                    .font(.system(size: 12, weight: .semibold)).lineLimit(2)
                                Text(bluetooth.connected ? "Connected · ready" : "Bluetooth")
                                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.muted)
                        }.padding(10).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).accessibilityIdentifier("connectEquipment")
                    if bluetooth.connected && !equipmentMatches {
                        Text("Choose a workout that matches your connected equipment.").font(.caption2).foregroundStyle(Palette.muted)
                    }
                    NavigationLink { ActivitySelectionView(selection: $activity) } label: {
                        HStack {
                            Text("Workout")
                            Spacer(minLength: 4)
                            Text(activity.title).font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    .accessibilityIdentifier("activityPicker")
                    Button("Record without equipment") { Task { await workout.start(activity: activity) } }
                        .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                Rectangle().fill(Color(white: 0.16)).frame(height: 1).padding(.vertical, 2)
                HStack(spacing: 8) {
                    NavigationLink { HistoryView() } label: {
                        Label("History", systemImage: "clock.arrow.circlepath").font(.system(size: 10, weight: .medium))
                    }.accessibilityLabel("Workout history")
                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "slider.horizontal.3").font(.system(size: 10, weight: .medium))
                    }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
                }.buttonStyle(RideButtonStyle(tint: .white))
                NavigationLink { ZoneSettingsView() } label: {
                    Label("Training zones", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .medium))
                }.buttonStyle(RideButtonStyle(tint: Palette.muted)).accessibilityIdentifier("trainingZones")
                Button("Try demo ride") { Task { await workout.start(activity: activity, demo: true) } }
                    .font(.system(size: 11)).foregroundStyle(Palette.lime).buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .disabled(!workout.canStart)
                    .accessibilityIdentifier("demoRide")
            }.padding(.horizontal, 7).padding(.bottom, 16)
        }
        .watchHeader("BikeTrack", symbol: "bicycle")
        .confirmationDialog("Discard the unfinished local workout?", isPresented: $confirmRecoveryDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { workout.dismissRecovery() }
        }
    }
}

private struct ActivitySelectionView: View {
    @Binding var selection: ActivityKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(ActivityKind.allCases) { activity in
            Button {
                selection = activity
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Label(activity.title, systemImage: activity.symbol)
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 0)
                    if selection == activity { Image(systemName: "checkmark").foregroundStyle(Palette.lime) }
                }
            }.listRowBackground(Palette.panel)
        }.watchHeader("Workout", showsBackButton: true)
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
        .watchHeader("Equipment", showsBackButton: true)
        .onAppear { if !bluetooth.connected && bluetooth.selectedName == nil { bluetooth.scan() } }
        .onDisappear { bluetooth.stopScan() }
    }
}
