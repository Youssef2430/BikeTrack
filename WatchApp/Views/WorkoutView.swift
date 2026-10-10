import SwiftUI
import RideCore

struct WorkoutView: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            WorkoutControls().tag(0)
            LiveMetricsView().tag(1)
            WorkoutDetailsView().tag(2)
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
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    Circle().fill(workout.phase == .paused ? .orange : Palette.lime).frame(width: 5, height: 5)
                    Text(workout.isDemo ? "DEMO" : workout.phase == .paused ? "PAUSED" : "RECORDING")
                        .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.3)
                    Spacer()
                    if !workout.isDemo && !bluetooth.connected {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.orange)
                            .font(.system(size: 10)).accessibilityLabel("Equipment disconnected")
                    }
                }
                Text(MetricFormat.elapsed(workout.elapsed))
                    .font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Palette.lime).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Elapsed time \(MetricFormat.elapsed(workout.elapsed))")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(primary(at: now))
                        .font(.system(size: 49, weight: .semibold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(workout.activity == .cycling ? "W" : imperial ? "MPH" : "KM/H")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(workout.activity == .cycling ? "Power" : "Speed")
                .accessibilityValue(primary(at: now))
                HStack {
                    smallMetric(symbol: "heart.fill", value: format(workout.heartRate), unit: "BPM", color: Palette.coral)
                    Spacer()
                    if workout.activity == .cycling {
                        smallMetric(symbol: "arrow.trianglehead.2.clockwise.rotate.90", value: format(workout.engine.cadence?.fresh(at: now)), unit: "RPM", color: Palette.blue)
                    } else {
                        smallMetric(symbol: "flame.fill", value: format(workout.energyKcal), unit: "KCAL", color: .orange)
                    }
                }
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.engine.distanceMethod == .unavailable ? "—" : MetricFormat.distance(workout.engine.distanceMeters, imperial: imperial))
                        .font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(imperial ? "MI" : "KM").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    Spacer()
                    Image(systemName: workout.activity.symbol)
                        .resizable().scaledToFit().frame(width: 26, height: 26)
                        .foregroundStyle(Palette.lime)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 6)
            .opacity(workout.phase == .paused ? 0.7 : 1)
        }
    }

    private func primary(at date: Date) -> String {
        if workout.phase == .paused { return "—" }
        if workout.activity == .cycling { return format(workout.engine.power?.fresh(at: date)) }
        guard let kph = workout.engine.speed?.fresh(at: date) else { return "—" }
        return String(format: "%.1f", kph / (imperial ? 1.609344 : 1))
    }

    private func format(_ value: Double?) -> String { value.map { String(format: "%.0f", $0) } ?? "—" }

    private func smallMetric(symbol: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10)).foregroundStyle(color)
                Text(unit).font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted)
            }
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
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
