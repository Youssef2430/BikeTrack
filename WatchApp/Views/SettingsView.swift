import SwiftUI

struct SettingsView: View {
    @AppStorage("imperial") private var imperial = false
    @AppStorage("wheelDistance") private var wheelDistance = false
    @AppStorage("wheelMM") private var wheelMM = 2105.0
    @StateObject private var log = DiagnosticLog.shared

    var body: some View {
        Form {
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
                Text("Free to use. No accounts. No subscriptions. Your workouts stay on your devices and in Apple Health.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Text("Connects to standard FTMS, Cycling Power, and Cycling Speed & Cadence services. Equipment must broadcast compatible data.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }.navigationTitle("Settings")
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
