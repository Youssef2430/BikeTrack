import SwiftUI
import RideCore

struct WorkoutView: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            WorkoutControls().tag(0)
            LiveMetricsView().tag(1)
            LiveZoneView(metric: .heartRate).tag(2)
            if workout.activity == .cycling { LiveZoneView(metric: .power).tag(3) }
            WorkoutDetailsView().tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .accessibilityIdentifier("workoutPages")
    }
}

struct LiveMetricsView: View {
    @EnvironmentObject private var workout: WorkoutController
    @EnvironmentObject private var bluetooth: BluetoothManager
    @AppStorage("imperial") private var imperial = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(MetricFormat.elapsed(workout.elapsed))
                            .font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit()
                        Spacer(minLength: 2)
                        Text(workout.isDemo ? "DEMO" : workout.phase == .paused ? "PAUSED" : "RECORDING")
                            .font(.system(size: 8, weight: .bold)).tracking(0.7)
                            .foregroundStyle(workout.phase == .paused ? Palette.coral : Palette.lime)
                    }
                    if workout.activity == .cycling {
                        HStack(spacing: 6) {
                            liveCard(.power, at: context.date)
                            liveCard(.heartRate, at: context.date)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(workout.phase == .paused ? "—" : workout.engine.speed?.fresh(at: context.date).map {
                                String(format: "%.1f", $0 / (imperial ? 1.609344 : 1))
                            } ?? "—").font(.system(size: 35, weight: .semibold, design: .rounded))
                            Text(imperial ? "mph" : "km/h").font(.caption2).foregroundStyle(Palette.muted)
                            Spacer()
                        }.metricCard()
                    }
                    if workout.activity != .cycling { liveCard(.heartRate, at: context.date) }
                    HStack(spacing: 4) {
                        Image(systemName: workout.activity.symbol).foregroundStyle(Palette.lime)
                        Text(workout.engine.distanceMethod == .unavailable ? "—" : MetricFormat.distance(workout.engine.distanceMeters, imperial: imperial))
                        Text(imperial ? "mi" : "km").foregroundStyle(Palette.muted)
                        Spacer(minLength: 4)
                        if workout.activity == .cycling {
                            Text(workout.phase == .paused ? "—" : formatted(workout.engine.cadence?.fresh(at: context.date)))
                            Text("rpm").foregroundStyle(Palette.muted)
                        }
                    }.font(.system(size: 11, weight: .medium)).monospacedDigit().padding(.horizontal, 4)
                    if !workout.isDemo && !bluetooth.connected {
                        Label("Equipment disconnected", systemImage: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 10)).foregroundStyle(Palette.coral)
                    }
                }.padding(.horizontal, 3).padding(.bottom, 12)
            }
        }
    }

    private func liveCard(_ metric: ZoneMetric, at date: Date) -> some View {
        let value = workout.liveValue(for: metric, at: date)
        let profile = workout.analytics.profile
        let zone = profile.zone(for: value, metric: metric)
        return VStack(alignment: .leading, spacing: 5) {
            Label(metric == .heartRate ? "Heart" : "Power", systemImage: metric.symbol)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(metric.tint)
                .frame(height: 12)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted(value)).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.65).lineLimit(1)
                Text(metric.unit).font(.system(size: 8)).foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 36)
            Text(zone?.label ?? (profile.baseline(for: metric) == nil ? "Set up" : "—"))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(zone.map { Palette.zone($0.id) } ?? Palette.muted)
                .accessibilityIdentifier("\(metric.rawValue)ZoneBadge")
            ZoneStrip(profile: profile, metric: metric, selected: zone?.id)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

struct WorkoutControls: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var confirmDiscard = false
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(workout.isDemo ? "Demo workout" : workout.activity.title).font(.headline)
                Button { workout.pauseOrResume() } label: {
                    Label(workout.phase == .paused ? "Resume" : "Pause", systemImage: workout.phase == .paused ? "play.fill" : "pause.fill")
                }
                .tint(Palette.lime).buttonStyle(.borderedProminent).foregroundStyle(.black)
                .accessibilityIdentifier("pauseResume")
                Button { confirmEnd = true } label: {
                    Label(workout.isDemo ? "End demo" : "End & save", systemImage: "stop.fill")
                }
                .tint(Palette.coral)
                .accessibilityIdentifier("endWorkout")
                Button("Discard", role: .destructive) { confirmDiscard = true }
                    .font(.caption2).buttonStyle(.plain)
                    .accessibilityIdentifier("discardWorkout")
            }
            .padding(.horizontal, 3).padding(.bottom, 12)
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { Task { await workout.discard() } }
                .accessibilityIdentifier("confirmDiscard")
        }
        .confirmationDialog(workout.isDemo ? "End the demo?" : "End and save to Health?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button(workout.isDemo ? "End demo" : "Save workout") { workout.endAndSave() }
                .accessibilityIdentifier("confirmEnd")
        }
    }
}

struct WorkoutDetailsView: View {
    @EnvironmentObject private var workout: WorkoutController
    @EnvironmentObject private var bluetooth: BluetoothManager
    @AppStorage("imperial") private var imperial = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Session details").font(.headline)
                if workout.isDemo {
                    Label("Demo data", systemImage: "sparkles").foregroundStyle(Palette.lime)
                    Text("Simulated equipment and heart rate. Nothing is saved to Apple Health.").font(.footnote)
                } else {
                    Text(bluetooth.status).font(.footnote).foregroundStyle(bluetooth.connected ? Palette.lime : .orange)
                    if let last = bluetooth.lastPacket {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            if context.date.timeIntervalSince(last) > 5 {
                                Text("Waiting for equipment data…").font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                    if let notice = workout.healthNotice { Text(notice).font(.footnote).foregroundStyle(.orange) }
                }
                DetailRow(label: "Energy", value: workout.energyKcal.map { String(format: "%.0f kcal", $0) } ?? "—")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    DetailRow(label: "Speed", value: workout.engine.speed?.fresh(at: context.date).map {
                        String(format: "%.1f %@", $0 / (imperial ? 1.609344 : 1), imperial ? "mph" : "km/h")
                    } ?? "—")
                }
                Text(workout.engine.distanceMethod.label).font(.caption2).foregroundStyle(Palette.muted)
                if !workout.isDemo && workout.heartRate == nil {
                    Text("Heart rate may take a moment. Wear your Watch snugly and allow Heart Rate in Health permissions.")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            }.padding(.horizontal, 4).padding(.bottom, 12)
        }
    }
}

struct DetailRow: View {
    var label: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
