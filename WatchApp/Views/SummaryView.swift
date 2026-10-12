import SwiftUI
import RideCore

struct SummaryView: View {
    let record: WorkoutRecord
    var dismiss: (() -> Void)?
    @AppStorage("imperial") private var imperial = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(title: record.activity.title, color: Palette.lime)
                    Text(record.isDemo ? "Demo complete" : record.savedToHealth ? "Workout saved" : "Local summary")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityIdentifier("summaryTitle")
                    Text(record.isDemo ? "Nothing was written to Health." : record.savedToHealth ? "Ready in Apple Fitness & Health." : "This workout is not confirmed in Health.")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: "Active time")
                    InstrumentNumber(value: MetricFormat.elapsed(record.duration), height: 32)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(record.distanceMethod == .unavailable ? "—" : MetricFormat.distance(record.distanceMeters, imperial: imperial))
                            .font(.system(size: 26, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Palette.lime)
                        Eyebrow(title: imperial ? "Miles" : "Kilometers")
                    }.padding(.top, 2)
                }.padding(.vertical, 4)
                if let analytics = record.analytics {
                    insightLink(analytics, metric: .heartRate)
                    if record.activity == .cycling { insightLink(analytics, metric: .power) }
                } else {
                    if let hr = record.averageHeartRate { DetailRow(label: "Average heart rate", value: String(format: "%.0f bpm", hr)) }
                    if let power = record.averagePower { DetailRow(label: "Average power", value: String(format: "%.0f W", power)) }
                    Text("Charts are available for workouts recorded with the new version.").font(.caption2).foregroundStyle(Palette.muted)
                }
                if let energy = record.energyKcal { DetailRow(label: "Active energy", value: String(format: "%.0f kcal", energy)) }
                Text(record.distanceMethod.label).font(.caption2).foregroundStyle(Palette.muted)
                if let dismiss {
                    Button("Done", action: dismiss).buttonStyle(RideButtonStyle(prominent: true))
                        .accessibilityIdentifier("summaryDone")
                }
            }.padding(.horizontal, 8).padding(.vertical, 8)
        }
        .watchHeader("Summary", symbol: "flag.checkered", showsBackButton: dismiss == nil)
    }

    private func insightLink(_ analytics: WorkoutAnalytics, metric: ZoneMetric) -> some View {
        NavigationLink {
            WorkoutInsightsView(analytics: analytics, metric: metric, duration: record.duration)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(metric.title, systemImage: metric.symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(metric.tint)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatted(analytics.timeline(for: metric).average)).font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("\(metric.unit) avg").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                TrendChart(timeline: analytics.timeline(for: metric), metric: metric, profile: analytics.profile, compact: true)
                Text("View zones & analysis").font(.system(size: 10, weight: .medium)).foregroundStyle(metric.tint)
            }.metricCard()
        }.buttonStyle(.plain).accessibilityIdentifier("\(metric.rawValue)SummaryChart")
    }
}

struct SaveFailureView: View {
    @EnvironmentObject private var workout: WorkoutController
    @State private var confirmDiscard = false
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.arrow.circlepath").font(.largeTitle).foregroundStyle(.orange)
                Text("Save needs attention").font(.headline)
                Text(workout.errorMessage ?? "The workout is still held locally.").font(.footnote)
                Button("Retry save") { workout.retrySave() }.buttonStyle(RideButtonStyle(prominent: true))
                Button("Discard", role: .destructive) { confirmDiscard = true }
            }
        }
        .watchHeader("Save workout", symbol: "exclamationmark.arrow.circlepath", tint: Palette.coral)
        .confirmationDialog("Discard unsaved workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { Task { await workout.discard() } }
        }
    }
}

struct HistoryView: View {
    @StateObject private var store = LocalStore.shared
    var body: some View {
        List {
            if store.history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ActivityEmblem(symbol: "clock.arrow.circlepath", size: 40)
                    Text("Your first ride awaits.")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Your last 100 saved sessions appear here. Full workout data lives in Apple Health.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }.padding(.vertical, 10).listRowBackground(Color.black)
            }
            ForEach(store.history) { record in
                NavigationLink { SummaryView(record: record) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(record.activity.title, systemImage: record.activity.symbol)
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.lime)
                        Text(MetricFormat.elapsed(record.duration))
                            .font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 5)
                }.listRowBackground(Palette.panel)
            }
            if let error = store.storageError { Text(error).font(.footnote).foregroundStyle(.orange) }
        }.watchHeader("History", showsBackButton: true)
    }
}
