import SwiftUI
import RideCore

struct SettingsView: View {
    @AppStorage("imperial") private var imperial = false
    @AppStorage("wheelDistance") private var wheelDistance = false
    @AppStorage("wheelMM") private var wheelMM = 2105.0
    @StateObject private var log = DiagnosticLog.shared

    var body: some View {
        Form {
            Section("Training") {
                NavigationLink { ZoneSettingsView() } label: {
                    Label("Heart rate & power zones", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.lime)
                }.accessibilityIdentifier("settingsTrainingZones")
            }
            Section("Display") {
                Toggle("Miles & mph", isOn: $imperial)
            }
            Section("Wheel sensors") {
                Toggle("Use wheel distance", isOn: $wheelDistance)
                if wheelDistance {
                    Stepper(value: $wheelMM, in: 500...4000, step: 5) {
                        Text("\(Int(wheelMM)) mm").monospacedDigit()
                    }
                }
                Text("Only for a calibrated wheel sensor. Leave off for indoor bikes unless you know their effective wheel circumference. Machine distance takes priority.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
            Section("Troubleshooting") {
                Toggle("Capture diagnostics", isOn: $log.enabled)
                NavigationLink("View diagnostics") { DiagnosticsView() }
                Text("Local connection events and packet structure only. No heart-rate values or automatic uploads.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
            Section("BikeTrack 1.0") {
                NavigationLink("Privacy policy") { PrivacyPolicyView() }
                    .accessibilityIdentifier("privacyPolicy")
                Text("Free to use. No accounts. No subscriptions. Your workouts stay on your devices and in Apple Health.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Text("Connects to standard FTMS, Cycling Power, and Cycling Speed & Cadence services. Equipment must broadcast compatible data.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }.watchHeader("Settings", showsBackButton: true)
    }
}

struct PrivacyPolicyView: View {
    private var policy: String {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Read the BikeTrack privacy policy at https://youssef2430.github.io/BikeTrack/privacy.html"
        }
        return text
    }

    var body: some View {
        ScrollView {
            Text(policy)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .watchHeader("Privacy policy", showsBackButton: true)
    }
}

struct ZoneSettingsView: View {
    @AppStorage("maximumHeartRate") private var maximumHeartRate = 0.0
    @AppStorage("ftp") private var ftp = 0.0

    var body: some View {
        List {
            Section {
                NavigationLink { ThresholdEditor(metric: .heartRate, savedValue: $maximumHeartRate) } label: {
                    thresholdRow(.heartRate, value: maximumHeartRate)
                }.accessibilityIdentifier("editMaxHeartRate")
                NavigationLink { ThresholdEditor(metric: .power, savedValue: $ftp) } label: {
                    thresholdRow(.power, value: ftp)
                }.accessibilityIdentifier("editFTP")
            }
            Section {
                ForEach(ZoneMetric.allCases, id: \.self) { metric in
                    NavigationLink { ZoneRangesView(metric: metric) } label: {
                        Label("\(metric.title) zones", systemImage: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(metric.tint)
                    }.accessibilityIdentifier("\(metric.rawValue)ZoneEditor")
                }
                Text("Zones start from typical defaults: \(Int(TrainingProfile.defaultMaximumHeartRate)) bpm max heart rate and \(Int(TrainingProfile.defaultFunctionalThresholdPower)) W FTP. Set your measured values or adjust where each zone starts. Changes apply to your next workout.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }.watchHeader("Training zones", showsBackButton: true)
    }

    private func thresholdRow(_ metric: ZoneMetric, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(metric == .heartRate ? "Max heart rate" : "Cycling FTP", systemImage: metric.symbol)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(metric.tint)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(TrainingSettings.baseline(value, for: metric))) \(metric.unit)")
                    .font(.system(size: 28, weight: .medium, design: .rounded)).monospacedDigit()
                if value <= 0 { Eyebrow(title: "Default") }
            }
        }.padding(.vertical, 8)
    }
}

private struct ThresholdEditor: View {
    let metric: ZoneMetric
    @Binding var savedValue: Double
    @State private var draft = 0
    @Environment(\.dismiss) private var dismiss
    private var limits: ClosedRange<Int> { metric == .heartRate ? 80...240 : 20...1000 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(metric == .heartRate ? "Maximum heart rate" : "Functional threshold power")
                    .font(.headline).multilineTextAlignment(.center)
                Picker(metric.unit, selection: $draft) {
                    ForEach(limits, id: \.self) { Text("\($0) \(metric.unit)").tag($0) }
                }.frame(height: 85).labelsHidden().accessibilityIdentifier("thresholdPicker")
                Text("Use your measured value. Every zone scales with it.").font(.caption2).foregroundStyle(Palette.muted)
                Button("Save") { savedValue = Double(draft); dismiss() }
                    .buttonStyle(RideButtonStyle(tint: metric.tint, prominent: true))
                    .accessibilityIdentifier("saveThreshold")
                if savedValue > 0 {
                    Button("Use default") { savedValue = 0; dismiss() }
                        .buttonStyle(RideButtonStyle(tint: Palette.muted))
                        .accessibilityIdentifier("useDefaultThreshold")
                }
            }.padding(.horizontal, 8).padding(.bottom, 12)
        }
        .watchHeader(metric.title, tint: metric.tint, showsBackButton: true)
        .onAppear { draft = Int(TrainingSettings.baseline(savedValue, for: metric)) }
    }
}

/// Lists the zones that the next workout will use; each zone above the first can move its start.
struct ZoneRangesView: View {
    let metric: ZoneMetric
    @AppStorage private var savedBaseline: Double
    @AppStorage private var savedEdges: String

    init(metric: ZoneMetric) {
        self.metric = metric
        _savedBaseline = AppStorage(wrappedValue: 0, TrainingSettings.baselineKey(metric))
        _savedEdges = AppStorage(wrappedValue: "", TrainingSettings.edgesKey(metric))
    }

    private var baseline: Double { TrainingSettings.baseline(savedBaseline, for: metric) }
    private var edges: [Double] {
        TrainingSettings.decode(savedEdges).flatMap { TrainingProfile.isValid($0, for: metric) ? $0 : nil }
            ?? TrainingProfile.defaultEdges(for: metric)
    }
    private var profile: TrainingProfile {
        metric == .heartRate ? TrainingProfile(maximumHeartRate: baseline, heartRateEdges: edges)
                             : TrainingProfile(functionalThresholdPower: baseline, powerEdges: edges)
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(profile.zones(for: metric).enumerated()), id: \.element.id) { index, zone in
                    if index == 0 {
                        row(zone)
                    } else {
                        NavigationLink {
                            ZoneStartEditor(metric: metric, zone: zone, index: index - 1, edges: edges,
                                            baseline: baseline, savedEdges: $savedEdges)
                        } label: { row(zone) }
                            .accessibilityIdentifier("\(metric.rawValue)ZoneStart\(zone.id)")
                    }
                }
            }
            Section {
                Text("Tap a zone to change where it starts. Zones scale with your \(metric == .heartRate ? "max heart rate" : "FTP") of \(Int(baseline)) \(metric.unit).")
                    .font(.caption2).foregroundStyle(Palette.muted)
                if !savedEdges.isEmpty {
                    Button("Use standard zones") { savedEdges = "" }
                        .accessibilityIdentifier("\(metric.rawValue)StandardZones")
                }
            }
        }.watchHeader("\(metric.title) zones", tint: metric.tint, showsBackButton: true)
    }

    private func row(_ zone: TrainingZone) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(zone.label == zone.name ? zone.label : "\(zone.label) · \(zone.name)")
                .font(.caption).foregroundStyle(Palette.zone(zone.id))
            Text("\(zone.range) \(metric.unit)").font(.caption2).monospacedDigit()
        }
    }
}

private struct ZoneStartEditor: View {
    let metric: ZoneMetric
    let zone: TrainingZone
    /// The position of this zone's start in the profile's edges.
    let index: Int
    let edges: [Double]
    let baseline: Double
    @Binding var savedEdges: String
    @State private var draft = 0
    @Environment(\.dismiss) private var dismiss

    /// Each start stays strictly between its neighbours, so no zone can vanish.
    private var limits: ClosedRange<Int> {
        let lower = index > 0 ? Int((edges[index - 1] * baseline).rounded(.down)) + 1 : 1
        let upper = index < edges.count - 1
            ? Int((edges[index + 1] * baseline).rounded(.up)) - 1
            : Int(baseline * (metric == .heartRate ? 1.1 : 2.5))
        return lower...max(lower, upper)
    }

    private var updated: [Double] {
        var edges = edges
        edges[index] = Double(draft) / baseline
        return edges
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("\(zone.name) starts at").font(.headline).multilineTextAlignment(.center)
                Picker(metric.unit, selection: $draft) {
                    ForEach(limits, id: \.self) { Text("\($0) \(metric.unit)").tag($0) }
                }.frame(height: 85).labelsHidden().accessibilityIdentifier("zoneStartPicker")
                Text("\(Int((Double(draft) / baseline * 100).rounded()))% of \(metric == .heartRate ? "max heart rate" : "FTP")")
                    .font(.caption2).foregroundStyle(Palette.muted)
                Button("Save") { savedEdges = TrainingSettings.encode(updated); dismiss() }
                    .buttonStyle(RideButtonStyle(tint: Palette.zone(zone.id), prominent: true))
                    .disabled(!TrainingProfile.isValid(updated, for: metric))
                    .accessibilityIdentifier("saveZoneStart")
            }.padding(.horizontal, 8).padding(.bottom, 12)
        }
        .watchHeader(zone.label, tint: Palette.zone(zone.id), showsBackButton: true)
        .onAppear { draft = min(limits.upperBound, max(limits.lowerBound, Int((edges[index] * baseline).rounded()))) }
    }
}

struct DiagnosticsView: View {
    @StateObject private var log = DiagnosticLog.shared
    var body: some View {
        List {
            if log.lines.isEmpty { Text("Enable capture, then connect your equipment to collect events.").font(.footnote) }
            else {
                ShareLink(item: "BikeTrack diagnostics\n" + log.lines.joined(separator: "\n")) {
                    Label("Share diagnostics", systemImage: "square.and.arrow.up")
                }
            }
            ForEach(Array(log.lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 10, design: .monospaced))
            }
            Button("Clear log", role: .destructive) { log.clear() }
        }.watchHeader("Diagnostics", showsBackButton: true)
    }
}
