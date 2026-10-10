import Foundation
import RideCore
import os

@MainActor
final class LocalStore: ObservableObject {
    static let shared = LocalStore()
    @Published private(set) var history: [WorkoutRecord] = []
    @Published private(set) var storageError: String?
    private let logger = Logger(subsystem: "com.youssefchouay.biketrack.watchapp", category: "storage")
    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BikeTrack", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            if let data = try read("history.json") {
                history = try JSONDecoder().decode([WorkoutRecord].self, from: data)
            }
        } catch { report(error) }
    }

    func write<T: Encodable>(_ value: T, to name: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func read(_ name: String) throws -> Data? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func remove(_ name: String) {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) } catch { report(error) }
    }

    func save(_ record: WorkoutRecord) {
        history.removeAll { $0.id == record.id }
        history.insert(record, at: 0)
        history = Array(history.prefix(100))
        do { try write(history, to: "history.json") } catch { report(error) }
    }

    func report(_ error: Error) {
        storageError = "Local storage: \(error.localizedDescription)"
        logger.error("Storage error: \(error.localizedDescription, privacy: .public)")
    }
}

/// Opt-in local diagnostics. No account, analytics SDK, or upload endpoint.
/// Heart-rate values and HealthKit samples are deliberately excluded.
@MainActor
final class DiagnosticLog: ObservableObject {
    static let shared = DiagnosticLog()
    @Published var enabled = false
    @Published private(set) var lines: [String] = []
    private var lastPacketLog = Date.distantPast

    func add(_ message: String) {
        guard enabled else { return }
        lines.append("\(Date().formatted(date: .omitted, time: .standard))  \(message)")
        if lines.count > 150 { lines.removeFirst(lines.count - 150) }
    }

    func packet(_ data: Data, source: PacketSource) {
        guard enabled, Date().timeIntervalSince(lastPacketLog) >= 2 else { return }
        lastPacketLog = Date()
        // Raw FTMS packets can contain heart rate. Keep structural information only.
        let flags = data.prefix(source == .speedCadence ? 1 : 2).map { String(format: "%02X", $0) }.joined()
        add("\(source.rawValue) flags=\(flags) bytes=\(data.count)")
    }

    func clear() { lines.removeAll() }
}
