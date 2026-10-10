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
                NavigationLink("Heart rate & power zones") { ZoneSettingsView() }
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
        }.navigationTitle("Settings")
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
        .navigationTitle("Privacy policy")
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
                Text("Use your measured maximum heart rate and cycling FTP. Changes apply to your next workout.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Text("Heart rate: five zones from 50% of max, in 10% steps, plus below Zone 1. Power: seven zones based on FTP.")
                    .font(.caption2).foregroundStyle(Palette.muted)
                ForEach(ZoneMetric.allCases, id: \.self) { metric in
                    if TrainingSettings.profile.baseline(for: metric) != nil {
                        NavigationLink("\(metric.title) ranges") { ZoneRangesView(profile: TrainingSettings.profile, metric: metric) }
                    }
                }
            }
        }.navigationTitle("Training zones")
    }

    private func thresholdRow(_ metric: ZoneMetric, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(metric == .heartRate ? "Max heart rate" : "Cycling FTP", systemImage: metric.symbol)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(metric.tint)
            Text(value > 0 ? "\(Int(value)) \(metric.unit)" : "Set up")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
        }.padding(.vertical, 5)
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
            VStack(spacing: 10) {
                Text(metric == .heartRate ? "Maximum heart rate" : "Functional threshold power")
                    .font(.headline).multilineTextAlignment(.center)
                Picker(metric.unit, selection: $draft) {
                    ForEach(limits, id: \.self) { Text("\($0) \(metric.unit)").tag($0) }
                }.frame(height: 85).labelsHidden().accessibilityIdentifier("thresholdPicker")
                Text("Choose your own measured value.").font(.caption2).foregroundStyle(Palette.muted)
                Button("Save") { savedValue = Double(draft); dismiss() }
                    .buttonStyle(.borderedProminent).tint(metric.tint).foregroundStyle(.black)
                    .accessibilityIdentifier("saveThreshold")
                if savedValue > 0 {
                    Button("Clear value", role: .destructive) { savedValue = 0; dismiss() }
                }
            }
        }
        .onAppear { draft = savedValue > 0 ? Int(savedValue) : (metric == .heartRate ? 190 : 240) }
    }
}

struct ZoneRangesView: View {
    let profile: TrainingProfile
    let metric: ZoneMetric
    var body: some View {
        List(profile.zones(for: metric)) { zone in
            VStack(alignment: .leading, spacing: 3) {
                Text("\(zone.label) · \(zone.name)").font(.caption).foregroundStyle(Palette.zone(zone.id))
                Text("\(zone.range) \(metric.unit)").font(.caption2)
            }
        }.navigationTitle(metric.title)
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
        }.navigationTitle("Diagnostics")
    }
}
