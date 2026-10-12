import SwiftUI
import RideCore

struct WorkoutView: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var page = 1

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                WorkoutControls().tag(0)
                LiveMetricsView().tag(1)
                LiveZoneView(metric: .heartRate).tag(2)
                if workout.activity == .cycling { LiveZoneView(metric: .power).tag(3) }
                WorkoutDetailsView().tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .accessibilityIdentifier("workoutPages")
            .watchHeader(headerTitle, symbol: headerSymbol, tint: visibleMetric?.tint ?? Palette.lime)
        }
    }

    private var visibleMetric: ZoneMetric? {
        switch page {
        case 2: .heartRate
        case 3: workout.activity == .cycling ? .power : nil
        default: nil
        }
    }

    private var headerTitle: String {
        if let visibleMetric { return visibleMetric.title }
        switch page {
        case 0: return "Controls"
        case 4: return "Details"
        default: return workout.activity.title
        }
    }

    private var headerSymbol: String {
        if let visibleMetric { return visibleMetric.symbol }
        switch page {
        case 0: return "slider.horizontal.3"
        case 4: return "list.bullet"
        default: return workout.activity.symbol
        }
    }
}

struct LiveMetricsView: View {
    @EnvironmentObject private var workout: WorkoutController
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1
    @AppStorage("imperial") private var imperial = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 190 || geometry.size.height < 150
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let power = workout.liveValue(for: .power, at: context.date)
                let heart = workout.liveValue(for: .heartRate, at: context.date)
                let elapsed = MetricFormat.elapsed(workout.elapsed)
                let longTimer = elapsed.count > 5
                let sectionSpacing: CGFloat = longTimer ? (compact ? 3 : 10) : (compact ? 9 : 15)
                let footerSpacing: CGFloat = longTimer ? (compact ? 4 : 7) : (compact ? 7 : 10)
                ScrollView {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        elapsedDisplay(elapsed, compact: compact)
                        let columns = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                        columns {
                            reading(value: workout.activity == .cycling ? formatted(power) : speed(at: context.date),
                                    unit: workout.activity == .cycling ? "WATTS" : imperial ? "MPH" : "KM/H",
                                    symbol: workout.activity == .cycling ? "bolt.fill" : "speedometer",
                                    color: Palette.lime, compact: compact,
                                    metric: workout.activity == .cycling ? .power : nil, sample: power)
                            reading(value: formatted(heart), unit: "BPM", symbol: "heart.fill",
                                    color: Palette.coral, compact: compact, metric: .heartRate, sample: heart)
                        }
                        VStack(spacing: footerSpacing) {
                            Rectangle().fill(Color(white: 0.18)).frame(height: 1)
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) {
                                    distance
                                    Spacer(minLength: 10)
                                    if workout.activity == .cycling { cadence(at: context.date) }
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    distance
                                    if workout.activity == .cycling { cadence(at: context.date) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if !workout.isDemo && !bluetooth.connected {
                            Label("Equipment disconnected", systemImage: "antenna.radiowaves.left.and.right.slash")
                                .font(.caption2).foregroundStyle(Palette.coral)
                        }
                    }
                    .padding(.horizontal, compact ? 9 : 12)
                    .padding(.top, compact ? 0 : 3)
                    .padding(.bottom, 22)
                }
            }
        }
    }

    @ViewBuilder
    private func elapsedDisplay(_ elapsed: String, compact: Bool) -> some View {
        // Hours get the full width. Keep the numbers readable instead of squeezing
        // a longer timer alongside the workout status on the smallest watches.
        if elapsed.count > 5 || typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
                status(horizontal: true)
                timer(elapsed, height: compact ? 24 : 34)
            }
        } else {
            HStack(spacing: 8) {
                timer(elapsed, height: compact ? 30 : 40)
                status(horizontal: false)
            }
        }
    }

    private func timer(_ elapsed: String, height: CGFloat) -> some View {
        InstrumentNumber(value: elapsed, height: height)
            .accessibilityLabel("Elapsed time, \(elapsed)")
            .accessibilityIdentifier("liveElapsedTime")
    }

    private func status(horizontal: Bool) -> some View {
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 5)) : AnyLayout(VStackLayout(spacing: 4))
        return layout {
            Image(systemName: workout.phase == .paused ? "pause.fill" : workout.activity.symbol)
                .font(.system(size: 13, weight: .semibold))
                .accessibilityLabel(workout.activity.title)
            Text(workout.phase == .paused ? "PAUSED" : workout.isDemo ? "DEMO" : "LIVE")
                .font(.system(size: 8 * textScale, weight: .bold)).tracking(0.5)
                .accessibilityLabel(workout.phase == .paused ? "PAUSED" : workout.isDemo ? "DEMO" : "RECORDING")
        }
        .foregroundStyle(workout.phase == .paused ? Palette.coral : Palette.lime)
        .fixedSize()
    }

    private func reading(value: String, unit: String, symbol: String, color: Color,
                         compact: Bool, metric: ZoneMetric?, sample: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(unit, systemImage: symbol)
                .font(.system(size: 9 * textScale, weight: .semibold)).tracking(0.7)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: (compact ? 30 : 38) * textScale, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityLabel("\(value) \(unit.lowercased())")
                .accessibilityIdentifier(metric.map { "\($0.rawValue)LiveReading" } ?? "speedLiveReading")
            if let metric { zoneLabel(for: metric, value: sample) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var distance: some View {
        footerMetric(value: workout.engine.distanceMethod == .unavailable ? "—" : MetricFormat.distance(workout.engine.distanceMeters, imperial: imperial),
                     unit: imperial ? "MI" : "KM", identifier: "liveDistance")
    }

    private func cadence(at date: Date) -> some View {
        footerMetric(value: workout.phase == .paused ? "—" : formatted(workout.engine.cadence?.fresh(at: date)),
                     unit: "RPM", identifier: "liveCadence")
    }

    private func footerMetric(value: String, unit: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.system(size: 12 * textScale, weight: .medium, design: .rounded)).monospacedDigit()
            Text(unit).font(.system(size: 9 * textScale, weight: .medium)).foregroundStyle(Palette.muted)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func speed(at date: Date) -> String {
        guard workout.phase != .paused else { return "—" }
        return workout.engine.speed?.fresh(at: date).map {
            String(format: "%.1f", $0 / (imperial ? 1.609344 : 1))
        } ?? "—"
    }

    private func zoneLabel(for metric: ZoneMetric, value: Double?) -> some View {
        let zone = workout.analytics.profile.zone(for: value, metric: metric)
        return Text(zone?.label ?? (workout.analytics.profile.baseline(for: metric) == nil ? "Set up zones" : "—"))
            .font(.system(size: 10 * textScale, weight: .medium))
            .foregroundStyle(zone.map { Palette.zone($0.id) } ?? Palette.muted)
            .lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityIdentifier("\(metric.rawValue)ZoneBadge")
    }
}

struct WorkoutControls: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var confirmDiscard = false
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ActivityEmblem(symbol: workout.activity.symbol, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.isDemo ? "Demo workout" : workout.activity.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(MetricFormat.elapsed(workout.elapsed))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                }.padding(.bottom, 2)
                Button { workout.pauseOrResume() } label: {
                    Label(workout.phase == .paused ? "Resume" : "Pause", systemImage: workout.phase == .paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(RideButtonStyle(prominent: true))
                .accessibilityIdentifier("pauseResume")
                Button { confirmEnd = true } label: {
                    Label(workout.isDemo ? "End demo" : "End & save", systemImage: "stop.fill")
                }
                .buttonStyle(RideButtonStyle(tint: Palette.coral))
                .accessibilityIdentifier("endWorkout")
                Button("Discard", role: .destructive) { confirmDiscard = true }
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 30).buttonStyle(.plain)
                    .accessibilityIdentifier("discardWorkout")
            }.padding(.horizontal, 8).padding(.bottom, 24)
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
            VStack(alignment: .leading, spacing: 14) {
                if workout.isDemo {
                    Label("Demo data", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.lime)
                    Text("Simulated equipment and heart rate. Nothing is saved to Apple Health.")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
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
            }.padding(.horizontal, 10).padding(.bottom, 24)
        }
    }
}

struct DetailRow: View {
    var label: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Eyebrow(title: label)
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
