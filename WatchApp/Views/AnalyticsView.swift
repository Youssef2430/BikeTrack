import SwiftUI
import Charts
import RideCore

extension ZoneMetric {
    var tint: Color { self == .heartRate ? Palette.coral : Palette.lime }
    var symbol: String { self == .heartRate ? "heart.fill" : "bolt.fill" }
}

extension View {
    func metricCard() -> some View {
        self.padding(12)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TrendChart: View {
    let timeline: MetricTimeline
    let metric: ZoneMetric
    var profile = TrainingProfile()
    var compact = false
    var height: CGFloat = 90
    private var lower: Double { max(0, (timeline.points.map(\.value).min() ?? 0) - (metric == .heartRate ? 10 : 25)) }
    private var upper: Double { max(lower + 20, (timeline.points.map(\.value).max() ?? 100) + (metric == .heartRate ? 10 : 25)) }

    private func zoneGradient(lower: Double, upper: Double, opacity: Double = 1) -> LinearGradient {
        let zones = profile.zones(for: metric)
        guard !zones.isEmpty else {
            return LinearGradient(colors: [metric.tint.opacity(opacity), metric.tint.opacity(opacity)], startPoint: .bottom, endPoint: .top)
        }
        var stops = [Gradient.Stop(color: Palette.zone(profile.zone(for: max(1, lower), metric: metric)?.id ?? zones[0].id).opacity(opacity), location: 0)]
        for (index, zone) in zones.enumerated() where index > 0 && zone.lowerBound > lower && zone.lowerBound < upper {
            let location = (zone.lowerBound - lower) / (upper - lower)
            stops.append(.init(color: Palette.zone(zones[index - 1].id).opacity(opacity), location: location))
            stops.append(.init(color: Palette.zone(zone.id).opacity(opacity), location: location))
        }
        stops.append(.init(color: Palette.zone(profile.zone(for: upper, metric: metric)?.id ?? zones.last!.id).opacity(opacity), location: 1))
        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    var body: some View {
        let domainLow = lower
        let domainHigh = upper
        let lineGradient = zoneGradient(lower: domainLow, upper: domainHigh)
        let areaGradient = zoneGradient(lower: domainLow, upper: domainHigh, opacity: 0.14)
        Group {
            if timeline.points.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.path").foregroundStyle(metric.tint)
                    Text("Waiting for \(metric.title.lowercased())…").font(.caption2).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, minHeight: compact ? 55 : height)
            } else {
                Chart {
                    ForEach(Array(timeline.points.enumerated()), id: \.offset) { _, point in
                        AreaMark(x: .value("Active time", point.elapsed), yStart: .value("Base", domainLow), yEnd: .value(metric.title, point.value), series: .value("Segment", point.segment))
                            .foregroundStyle(areaGradient).alignsMarkStylesWithPlotArea()
                        LineMark(x: .value("Active time", point.elapsed), y: .value(metric.title, point.value), series: .value("Segment", point.segment))
                            .foregroundStyle(lineGradient).alignsMarkStylesWithPlotArea()
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    }
                    if let last = timeline.points.last {
                        PointMark(x: .value("Active time", last.elapsed), y: .value(metric.title, last.value))
                            .foregroundStyle(profile.zone(for: last.value, metric: metric).map { Palette.zone($0.id) } ?? metric.tint).symbolSize(12)
                    }
                }
                .chartYScale(domain: domainLow...domainHigh)
                .chartXScale(domain: 0...max(1, timeline.points.last?.elapsed ?? 1))
                .chartXAxis(.hidden)
                .chartYAxis {
                    if !compact {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
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
        GeometryReader { geometry in
            let compact = geometry.size.width < 190
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let value = workout.liveValue(for: metric, at: context.date)
                let zone = workout.analytics.profile.zone(for: value, metric: metric)
                let timeline = workout.analytics.timeline(for: metric)
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                        if metric == .heartRate {
                            let ribbon: CGFloat = compact ? 22 : 26
                            VStack(spacing: compact ? 6 : 8) {
                                // The dial yields height so the zone ribbon clears the page dots.
                                HeartRateDial(timeline: timeline, value: value,
                                              caption: workout.phase == .paused ? "PAUSED" : workout.isDemo ? "DEMO" : "LIVE",
                                              duration: workout.elapsed)
                                    .frame(maxHeight: max(100, geometry.size.height - ribbon * 1.12 - (compact ? 6 : 8)))
                                ZoneRibbon(profile: workout.analytics.profile, metric: metric, selected: zone?.id, height: ribbon)
                                zoneCaption(zone)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                                HStack(spacing: 8) {
                                    InstrumentNumber(value: MetricFormat.elapsed(workout.elapsed), height: compact ? 22 : 30)
                                    if workout.phase == .paused { Eyebrow(title: "Paused", color: Palette.coral) }
                                    else if workout.isDemo { Eyebrow(title: "Demo") }
                                }
                                ZoneRibbon(profile: workout.analytics.profile, metric: metric, selected: zone?.id, height: compact ? 22 : 26)
                                HStack(alignment: .bottom, spacing: 4) {
                                    InstrumentNumber(value: formatted(value), height: compact ? 30 : 40)
                                    Eyebrow(title: "Watts", color: metric.tint).padding(.bottom, 3)
                                }
                            }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                                Eyebrow(title: "Time in zone")
                                Text(zone.map { MetricFormat.elapsed(timeline.zoneSeconds[$0.id, default: 0]) } ?? "—")
                                    .font(.system(size: compact ? 21 : 23, weight: .medium, design: .rounded)).monospacedDigit()
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: compact ? 3 : 5) {
                                Eyebrow(title: "Average")
                                Text(formatted(timeline.average))
                                    .font(.system(size: compact ? 21 : 23, weight: .medium, design: .rounded)).monospacedDigit()
                            }
                        }
                        .padding(.top, metric == .heartRate ? 10 : 2)
                        .padding(.bottom, 2)
                        if metric == .power { zoneCaption(zone) }
                        Rectangle().fill(Color(white: 0.16)).frame(height: 1)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(title: "Session trend")
                            TrendChart(timeline: timeline, metric: metric, profile: workout.analytics.profile, height: 75)
                            chartTimeLabels(timeline)
                            ZoneScale(profile: workout.analytics.profile, metric: metric, value: value).padding(.top, 6)
                        }
                        ZoneDistribution(analytics: workout.analytics, metric: metric, duration: workout.elapsed).padding(.top, 8)
                    }.padding(.horizontal, 8).padding(.bottom, 28)
                }.accessibilityIdentifier("\(metric.rawValue)Insights")
            }
        }
    }

    private func zoneCaption(_ zone: TrainingZone?) -> some View {
        Text(zone.map(\.name) ?? (workout.phase == .paused ? "Paused" : workout.analytics.profile.baseline(for: metric) == nil ? "Set up training zones" : "Waiting for signal"))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(zone.map { Palette.zone($0.id) } ?? Palette.muted)
            .frame(maxWidth: .infinity, alignment: metric == .heartRate ? .center : .leading)
            .accessibilityIdentifier("\(metric.rawValue)LiveZone")
    }
}

struct WorkoutInsightsView: View {
    let analytics: WorkoutAnalytics
    let metric: ZoneMetric
    let duration: TimeInterval

    var body: some View {
        let timeline = analytics.timeline(for: metric)
        let averageZone = analytics.profile.zone(for: timeline.average, metric: metric)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if metric == .heartRate {
                    HeartRateDial(timeline: timeline, value: timeline.average, caption: "AVG", duration: duration)
                        .padding(.top, 8)
                    ZoneRibbon(profile: analytics.profile, metric: metric, selected: averageZone?.id)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(title: "Average power", color: metric.tint)
                        InstrumentNumber(value: formatted(timeline.average), height: 48, color: metric.tint)
                        Eyebrow(title: "Watts")
                    }.padding(.top, 8)
                }
                if let averageZone {
                    Text(metric == .heartRate ? averageZone.name : "\(averageZone.label) · \(averageZone.name)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.zone(averageZone.id))
                }
                ZoneScale(profile: analytics.profile, metric: metric, value: timeline.average)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: "Session trend")
                    TrendChart(timeline: timeline, metric: metric, profile: analytics.profile, height: 75)
                    chartTimeLabels(timeline)
                }.padding(.vertical, 4)
                ZoneDistribution(analytics: analytics, metric: metric, duration: duration)
                HStack {
                    Text("Peak \(metric.title.lowercased())").font(.caption2).foregroundStyle(Palette.muted)
                    Spacer(minLength: 3)
                    Text("\(formatted(timeline.peak)) \(metric.unit)").font(.caption2).monospacedDigit()
                }
            }.padding(.horizontal, 8).padding(.bottom, 16)
        }.watchHeader(metric.title, tint: metric.tint, showsBackButton: true)
    }
}

struct ZoneDistribution: View {
    let analytics: WorkoutAnalytics
    let metric: ZoneMetric
    let duration: TimeInterval
    @State private var showRanges = false
    private var timeline: MetricTimeline { analytics.timeline(for: metric) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time in zones").font(.system(size: 16, weight: .semibold, design: .rounded))
            if let baseline = analytics.profile.baseline(for: metric) {
                Text("\(metric == .heartRate ? "Max HR" : "FTP") \(Int(baseline)) \(metric.unit)")
                    .font(.caption2).foregroundStyle(Palette.muted)
                VStack(spacing: 0) {
                    HStack {
                        Text("Zone").frame(width: 25, alignment: .leading)
                        Text("Duration")
                        Spacer()
                        Text("%")
                    }.font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted).padding(.bottom, 6)
                    ForEach(analytics.profile.zones(for: metric)) { zone in
                        let seconds = timeline.zoneSeconds[zone.id, default: 0]
                        let fraction = timeline.recordedSeconds > 0 ? seconds / timeline.recordedSeconds : 0
                        let longest = timeline.zoneSeconds.values.max() ?? 0
                        let barFraction = longest > 0 ? seconds / longest : 0
                        HStack(spacing: 5) {
                            Text("\(zone.id)").foregroundStyle(Palette.zone(zone.id))
                                .font(.system(size: 11, weight: .bold)).frame(width: 15, alignment: .leading)
                            Text(MetricFormat.elapsed(seconds)).font(.system(size: 10, weight: .medium)).monospacedDigit()
                                .frame(width: 40, alignment: .leading).minimumScaleFactor(0.7).lineLimit(1)
                            GeometryReader { geometry in
                                Capsule().fill(Palette.zone(zone.id)).frame(width: geometry.size.width * min(1, barFraction))
                            }.frame(height: 5)
                            Text(String(format: "%.0f%%", fraction * 100)).font(.system(size: 10)).monospacedDigit()
                                .frame(width: 26, alignment: .trailing)
                        }.foregroundStyle(seconds > 0 ? .white : Palette.muted.opacity(0.65)).padding(.vertical, 9)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(zone.label), \(zone.name)")
                            .accessibilityValue("\(MetricFormat.elapsed(seconds)), \(Int((fraction * 100).rounded())) percent, \(zone.range) \(metric.unit)")
                            .accessibilityIdentifier("\(metric.rawValue)ZoneRow\(zone.id)")
                        if zone.id != analytics.profile.zones(for: metric).last?.id {
                            Divider().overlay(.white.opacity(0.03))
                        }
                    }
                }.metricCard()
                Button {
                    showRanges.toggle()
                } label: {
                    HStack {
                        Text("Zone ranges")
                        Spacer()
                        Image(systemName: showRanges ? "chevron.up" : "chevron.down")
                    }.font(.system(size: 11)).padding(.horizontal, 12)
                }.buttonStyle(RideButtonStyle(tint: .white)).accessibilityIdentifier("\(metric.rawValue)ZoneRanges")
                if showRanges {
                    ForEach(analytics.profile.zones(for: metric)) { zone in
                        HStack {
                            Text("Z\(zone.id)").foregroundStyle(Palette.zone(zone.id))
                            Spacer(minLength: 3)
                            Text("\(zone.range) \(metric.unit)")
                        }.font(.system(size: 10)).padding(.vertical, 3)
                    }
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

/// Equal-width bands match the reference's readable legend. The marker's
/// position within a band reflects the value within that band's numeric range.
struct ZoneScale: View {
    let profile: TrainingProfile
    let metric: ZoneMetric
    let value: Double?
    private var zones: [TrainingZone] { profile.zones(for: metric) }

    private var position: Double? {
        guard let value, let current = profile.zone(for: value, metric: metric),
              let index = zones.firstIndex(where: { $0.id == current.id }),
              let baseline = profile.baseline(for: metric) else { return nil }
        let upper = current.upperBound ?? baseline * (metric == .heartRate ? 1 : 2)
        let fraction = min(1, max(0, (value - current.lowerBound) / max(1, upper - current.lowerBound)))
        return (Double(index) + fraction) / Double(zones.count)
    }

    var body: some View {
        if !zones.isEmpty {
            VStack(spacing: 4) {
                HStack(spacing: 1) {
                    ForEach(zones) { zone in
                        Text("Z\(zone.id)").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Palette.zone(zone.id)).frame(maxWidth: .infinity)
                    }
                }
                GeometryReader { geometry in
                    HStack(spacing: 1) {
                        ForEach(zones) { zone in Rectangle().fill(Palette.zone(zone.id)) }
                    }.clipShape(Capsule())
                    if let position {
                        Circle().fill(Palette.panel).overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .frame(width: 7, height: 7)
                            .offset(x: min(geometry.size.width - 7, max(0, geometry.size.width * position - 3.5)), y: -0.5)
                    }
                }.frame(height: 6)
                HStack(spacing: 1) {
                    ForEach(zones) { zone in
                        Text("\(formatted(zone.lowerBound))\(zone.upperBound == nil ? "+" : "")")
                            .font(.system(size: 7)).monospacedDigit().foregroundStyle(Palette.muted)
                            .minimumScaleFactor(0.6).lineLimit(1).frame(maxWidth: .infinity)
                    }
                }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel("\(metric.title) zone scale")
                .accessibilityValue(profile.zone(for: value, metric: metric)?.label ?? "No current value")
                .accessibilityIdentifier("\(metric.rawValue)ZoneScale")
        }
    }
}

func formatted(_ value: Double?) -> String { value.map { String(format: "%.0f", $0) } ?? "—" }

func chartTimeLabels(_ timeline: MetricTimeline) -> some View {
    HStack {
        Text("0:00")
        Spacer()
        Text("Active time")
        Spacer()
        Text(MetricFormat.elapsed(timeline.points.last?.elapsed ?? 0))
    }.font(.system(size: 8)).foregroundStyle(Palette.muted).accessibilityHidden(true)
}
