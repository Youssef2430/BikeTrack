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
                    Image(systemName: record.savedToHealth ? "checkmark.circle.fill" : "flag.checkered.circle.fill")
                        .font(.system(size: 32)).foregroundStyle(Palette.lime)
                    Text(record.isDemo ? "Demo complete" : record.savedToHealth ? "Workout saved" : "Local summary")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("summaryTitle")
                    Text(record.isDemo ? "Nothing was written to Health." : record.savedToHealth ? "Ready in Apple Fitness & Health." : "This workout is not confirmed in Health.")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
                HStack(alignment: .top) {
                    compactStat("Duration", value: MetricFormat.elapsed(record.duration), unit: "active time", tint: .white)
                    Spacer(minLength: 5)
                    compactStat("Distance", value: record.distanceMethod == .unavailable ? "—" : MetricFormat.distance(record.distanceMeters, imperial: imperial), unit: imperial ? "mi" : "km", tint: Palette.lime)
                }
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
                    Button("Done", action: dismiss).buttonStyle(.borderedProminent).tint(Palette.lime).foregroundStyle(.black)
                        .accessibilityIdentifier("summaryDone")
                }
            }.padding(.horizontal, 5).padding(.vertical, 8)
        }
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
                    Text(formatted(analytics.timeline(for: metric).average)).font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("\(metric.unit) avg").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                TrendChart(timeline: analytics.timeline(for: metric), metric: metric, profile: analytics.profile, compact: true)
                Text("Explore zones").font(.system(size: 10)).foregroundStyle(Palette.muted)
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
                Button("Retry save") { workout.retrySave() }.buttonStyle(.borderedProminent)
                Button("Discard", role: .destructive) { confirmDiscard = true }
            }
        }
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
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.title).foregroundStyle(Palette.lime)
                    Text("Your first ride awaits.").font(.headline)
                    Text("Your last 100 saved sessions appear here. Full workout data lives in Apple Health.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            ForEach(store.history) { record in
                NavigationLink { SummaryView(record: record) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.activity.title).font(.headline)
                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(Palette.muted)
                        Text(MetricFormat.elapsed(record.duration)).foregroundStyle(Palette.lime).monospacedDigit()
                    }
                }
            }
            if let error = store.storageError { Text(error).font(.footnote).foregroundStyle(.orange) }
        }.navigationTitle("History")
    }
}
