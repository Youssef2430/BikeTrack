import SwiftUI
import Charts
import RideCore

extension ZoneMetric {
    var tint: Color { self == .heartRate ? Palette.coral : Palette.blue }
    var symbol: String { self == .heartRate ? "heart.fill" : "bolt.fill" }
}

extension View {
    func metricCard() -> some View {
        self.padding(10)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

struct ZoneStrip: View {
    let profile: TrainingProfile
    let metric: ZoneMetric
    let selected: Int?
    var body: some View {
        HStack(spacing: 3) {
            ForEach(profile.zones(for: metric)) { zone in
                Capsule().fill(Palette.zone(zone.id).opacity(selected == zone.id ? 1 : 0.22))
                    .frame(height: selected == zone.id ? 5 : 3)
            }
        }.frame(height: 5).accessibilityHidden(true)
    }
}

struct TrendChart: View {
    let timeline: MetricTimeline
    let metric: ZoneMetric
    var compact = false
    var height: CGFloat = 90
    private var lower: Double { max(0, (timeline.points.map(\.value).min() ?? 0) - (metric == .heartRate ? 10 : 25)) }
    private var upper: Double { max(lower + 20, (timeline.points.map(\.value).max() ?? 100) + (metric == .heartRate ? 10 : 25)) }

    var body: some View {
        Group {
            if timeline.points.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.path").foregroundStyle(metric.tint)
                    Text("Waiting for \(metric.title.lowercased())…").font(.caption2).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, minHeight: compact ? 55 : height)
            } else {
                Chart {
                    ForEach(Array(timeline.points.enumerated()), id: \.offset) { _, point in
                        AreaMark(x: .value("Active time", point.elapsed), yStart: .value("Base", lower), yEnd: .value(metric.title, point.value), series: .value("Segment", point.segment))
                            .foregroundStyle(LinearGradient(colors: [metric.tint.opacity(0.25), metric.tint.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Active time", point.elapsed), y: .value(metric.title, point.value), series: .value("Segment", point.segment))
                            .foregroundStyle(metric.tint).lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    }
                    if let last = timeline.points.last {
                        PointMark(x: .value("Active time", last.elapsed), y: .value(metric.title, last.value))
                            .foregroundStyle(metric.tint).symbolSize(12)
                    }
                }
                .chartYScale(domain: lower...upper)
                .chartXScale(domain: 0...max(1, timeline.points.last?.elapsed ?? 1))
                .chartXAxis(.hidden)
                .chartYAxis {
                    if !compact {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine().foregroundStyle(.white.opacity(0.07))
                            AxisValueLabel().font(.system(size: 9)).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: compact ? 55 : height)
                .accessibilityLabel("\(metric.title) chart")
                .accessibilityValue("Average \(formatted(timeline.average)) \(metric.unit), peak \(formatted(timeline.peak)) \(metric.unit)")
            }
        }
    }
}

struct LiveZoneView: View {
    @EnvironmentObject private var workout: WorkoutController
    let metric: ZoneMetric
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let value = workout.liveValue(for: metric, at: context.date)
            let zone = workout.analytics.profile.zone(for: value, metric: metric)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(metric.title, systemImage: metric.symbol).foregroundStyle(metric.tint)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer(minLength: 2)
                        if workout.isDemo { Text("DEMO").font(.system(size: 8, weight: .bold)).foregroundStyle(Palette.muted) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatted(value)).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text(metric.unit).font(.caption2).foregroundStyle(Palette.muted)
                            Spacer(minLength: 0)
                        }
                        Text(zone.map { "\($0.label) · \($0.name)" } ?? (workout.phase == .paused ? "Paused" : "No current zone"))
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(zone.map { Palette.zone($0.id) } ?? Palette.muted)
                            .accessibilityIdentifier("\(metric.rawValue)LiveZone")
                        ZoneStrip(profile: workout.analytics.profile, metric: metric, selected: zone?.id)
                    }
                    TrendChart(timeline: workout.analytics.timeline(for: metric), metric: metric, height: 60)
                    chartTimeLabels(workout.analytics.timeline(for: metric))
                    ZoneDistribution(analytics: workout.analytics, metric: metric, duration: workout.elapsed).padding(.top, 12)
                }.padding(.horizontal, 4).padding(.bottom, 18)
            }.accessibilityIdentifier("\(metric.rawValue)Insights")
        }
    }
}

struct WorkoutInsightsView: View {
    let analytics: WorkoutAnalytics
    let metric: ZoneMetric
    let duration: TimeInterval
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    compactStat("Average", value: formatted(analytics.timeline(for: metric).average), unit: metric.unit, tint: metric.tint)
                    Spacer()
                    compactStat("Peak", value: formatted(analytics.timeline(for: metric).peak), unit: metric.unit, tint: .white)
                }
                VStack(spacing: 6) {
                    TrendChart(timeline: analytics.timeline(for: metric), metric: metric)
                    chartTimeLabels(analytics.timeline(for: metric))
                }
                ZoneDistribution(analytics: analytics, metric: metric, duration: duration)
            }.padding(.horizontal, 4).padding(.bottom, 12)
        }.navigationTitle(metric.title)
    }
}

struct ZoneDistribution: View {
    let analytics: WorkoutAnalytics
    let metric: ZoneMetric
    let duration: TimeInterval
    private var timeline: MetricTimeline { analytics.timeline(for: metric) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time in zones").font(.system(size: 15, weight: .semibold))
            if let baseline = analytics.profile.baseline(for: metric) {
                Text("\(metric == .heartRate ? "Max HR" : "FTP") \(Int(baseline)) \(metric.unit)")
                    .font(.caption2).foregroundStyle(Palette.muted)
                ForEach(analytics.profile.zones(for: metric)) { zone in
                    let seconds = timeline.zoneSeconds[zone.id, default: 0]
                    let fraction = timeline.recordedSeconds > 0 ? seconds / timeline.recordedSeconds : 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(zone.id == 0 ? "< Z1" : "Z\(zone.id)").foregroundStyle(Palette.zone(zone.id))
                                .font(.system(size: 12, weight: .bold)).frame(width: 29, alignment: .leading)
                            Text(MetricFormat.elapsed(seconds)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                            Spacer(minLength: 3)
                            Text(String(format: "%.0f%%", fraction * 100)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        GeometryReader { geometry in
                            Capsule().fill(Palette.zone(zone.id).opacity(0.10))
                            Capsule().fill(Palette.zone(zone.id)).frame(width: geometry.size.width * min(1, fraction))
                        }.frame(height: 5)
                        Text("\(zone.name) · \(zone.range) \(metric.unit)")
                            .font(.system(size: 9)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }.metricCard()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(zone.label), \(zone.name)")
                        .accessibilityValue("\(MetricFormat.elapsed(seconds)), \(Int((fraction * 100).rounded())) percent, \(zone.range) \(metric.unit)")
                }
                Text("Percent of recorded \(metric.title.lowercased()) time. Pauses are excluded.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            } else {
                Text("Set your \(metric == .heartRate ? "maximum heart rate" : "FTP") in Training zones before your next workout to see zone breakdowns.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            HStack {
                Text("No signal").font(.caption2)
                Spacer()
                Text(MetricFormat.elapsed(max(0, duration - timeline.recordedSeconds))).font(.caption2).monospacedDigit()
            }.foregroundStyle(Palette.muted)
        }
    }
}

func formatted(_ value: Double?) -> String { value.map { String(format: "%.0f", $0) } ?? "—" }

func compactStat(_ label: String, value: String, unit: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(label).font(.system(size: 10)).foregroundStyle(Palette.muted)
        Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
        Text(unit).font(.system(size: 9)).foregroundStyle(Palette.muted)
    }
}

func chartTimeLabels(_ timeline: MetricTimeline) -> some View {
    HStack {
        Text("0:00")
        Spacer()
        Text("Active time")
        Spacer()
        Text(MetricFormat.elapsed(timeline.points.last?.elapsed ?? 0))
    }.font(.system(size: 8)).foregroundStyle(Palette.muted).accessibilityHidden(true)
}
