import Foundation
@preconcurrency import CoreBluetooth
import RideCore

struct Equipment: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
}

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    @Published private(set) var devices: [Equipment] = []
    @Published private(set) var status = "Connect your equipment"
    @Published private(set) var connected = false
    @Published private(set) var scanning = false
    @Published private(set) var selectedName: String?
    @Published private(set) var lastPacket: Date?
    @Published private(set) var availableSources: Set<PacketSource> = []
    var onPacket: ((BikePacket, PacketSource, Date) -> Void)?
    var onDisconnect: (() -> Void)?

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var current: CBPeripheral?
    private var desiredID: UUID?
    private var reconnectTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var retry = 0
    private var wantsScan = false
    private let services = ["1826", "1818", "1816"].map { CBUUID(string: $0) }
    private let characteristics = ["2AD2", "2ACD", "2A63", "2A5B"].map { CBUUID(string: $0) }

    override init() {
        super.init()
        // Main queue gives CoreBluetooth and the UI a single ordering of events.
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func scan() {
        wantsScan = true
        guard central.state == .poweredOn else { updateState(); return }
        guard current == nil else { return }
        devices.removeAll()
        scanning = true
        status = "Looking for equipment…"
        central.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self else { return }
            self.stopScan()
            self.status = self.devices.isEmpty ? "No equipment found. Wake it up and try again." : "Choose your equipment"
        }
    }

    func stopScan() {
        wantsScan = false
        scanning = false
        scanTask?.cancel()
        central.stopScan()
    }

    func connect(_ id: UUID) {
        guard let peripheral = peripherals[id] else { return }
        disconnect()
        desiredID = id
        current = peripheral
        selectedName = peripheral.name ?? "Fitness equipment"
        UserDefaults.standard.set(id.uuidString, forKey: "lastEquipment")
        attemptConnection()
    }

    func reconnectSaved() {
        guard current == nil, central.state == .poweredOn,
              let value = UserDefaults.standard.string(forKey: "lastEquipment"), let id = UUID(uuidString: value),
              let peripheral = central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        peripherals[id] = peripheral
        connect(id)
    }

    func disconnect() {
        desiredID = nil
        retry = 0
        reconnectTask?.cancel(); timeoutTask?.cancel()
        stopScan()
        let old = current
        current = nil
        if let old { central.cancelPeripheralConnection(old) }
        connected = false
        selectedName = nil
        lastPacket = nil
        availableSources.removeAll()
        status = "Connect your equipment"
        onDisconnect?()
    }

    private func attemptConnection() {
        guard central.state == .poweredOn, let current, current.identifier == desiredID else { return }
        status = retry == 0 ? "Connecting…" : "Reconnecting…"
        current.delegate = self
        central.connect(current)
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, weak current] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, let current, self.current === current, !self.connected else { return }
            self.central.cancelPeripheralConnection(current)
            self.scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard desiredID != nil, central.state == .poweredOn else { return }
        reconnectTask?.cancel()
        retry += 1
        let delay = min(30, pow(2, Double(min(retry, 5))))
        status = "Reconnecting… Keep equipment awake."
        DiagnosticLog.shared.add("Connection interrupted; retry \(retry)")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.attemptConnection()
        }
    }

    private func updateState() {
        switch central.state {
        case .poweredOn:
            if desiredID != nil { attemptConnection() }
            else if wantsScan { scan() }
            else { status = "Connect your equipment" }
        case .poweredOff: status = "Turn on Bluetooth in Watch Settings."
        case .unauthorized: status = "Allow Bluetooth for BikeTrack in Settings."
        case .unsupported: status = "Bluetooth equipment requires a real Apple Watch."
        case .resetting: status = "Bluetooth is restarting…"
        case .unknown: status = "Starting Bluetooth…"
        @unknown default: status = "Bluetooth is unavailable."
        }
        if central.state != .poweredOn {
            connected = false; scanning = false; lastPacket = nil
            availableSources.removeAll()
            reconnectTask?.cancel(); timeoutTask?.cancel()
            onDisconnect?()
        }
    }
}

// These delegates are explicitly delivered on .main by the central manager.
extension BluetoothManager: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) { updateState() }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Fitness equipment"
        let device = Equipment(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index] = device }
        else { devices.append(device) }
        devices.sort { $0.rssi > $1.rssi }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard current === peripheral, desiredID == peripheral.identifier else {
            central.cancelPeripheralConnection(peripheral); return
        }
        status = "Checking sensors…"
        availableSources.removeAll()
        peripheral.discoverServices(services)
        DiagnosticLog.shared.add("Connected; discovering supported services")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard current === peripheral else { return }
        scheduleReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard current === peripheral else { return }
        connected = false; lastPacket = nil; availableSources.removeAll()
        onDisconnect?()
        scheduleReconnect()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard current === peripheral else { return }
        guard error == nil, let found = peripheral.services, !found.isEmpty else {
            status = "No supported fitness service on this device."
            DiagnosticLog.shared.add("Service discovery failed")
            return
        }
        for service in found { peripheral.discoverCharacteristics(characteristics, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard current === peripheral else { return }
        guard error == nil else { DiagnosticLog.shared.add("Characteristic discovery failed"); return }
        for characteristic in service.characteristics ?? [] {
            guard PacketSource(rawValue: characteristic.uuid.uuidString) != nil else { continue }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard current === peripheral else { return }
        guard error == nil, characteristic.isNotifying, let source = PacketSource(rawValue: characteristic.uuid.uuidString) else {
            DiagnosticLog.shared.add("Could not subscribe to \(characteristic.uuid.uuidString)")
            return
        }
        availableSources.insert(source)
        connected = true
        retry = 0
        timeoutTask?.cancel(); reconnectTask?.cancel()
        status = "Connected · start moving"
        DiagnosticLog.shared.add("Subscribed to \(source.rawValue)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard current === peripheral, error == nil, let data = characteristic.value,
              let source = PacketSource(rawValue: characteristic.uuid.uuidString) else { return }
        do {
            let packet = try BluetoothPackets.parse(data, source: source)
            lastPacket = Date()
            status = "Equipment connected"
            DiagnosticLog.shared.packet(data, source: source)
            onPacket?(packet, source, lastPacket!)
        } catch {
            DiagnosticLog.shared.add("Ignored malformed \(source.rawValue) packet (\(data.count) bytes)")
        }
    }
}
