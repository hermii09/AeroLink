import CoreBluetooth
import Foundation

/// Receives framed JSON HealthReading messages over small GATT writes.
final class HealthPeripheral: NSObject, CBPeripheralManagerDelegate {
    static let serviceID = CBUUID(string: "A3C5E000-4C8A-4D1E-9B3A-2E7C0D91A610")
    static let readingID = CBUUID(string: "A3C5E001-4C8A-4D1E-9B3A-2E7C0D91A610")

    private let onReading: (HealthReading, @escaping (Bool) -> Void) -> Void
    private var manager: CBPeripheralManager?
    var onState: ((Bool, String) -> Void)?
    private var servicePublished = false
    private var serviceAdding = false
    private var assembly: Assembly?

    private struct Assembly {
        let messageID: UInt16
        let count: Int
        var nextIndex: Int
        var bytes: Data
    }

    init(onReading: @escaping (HealthReading, @escaping (Bool) -> Void) -> Void) {
        self.onReading = onReading
        super.init()
        // No restoration identifier: this receiver has no state-restoration delegate.
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func start() {
        guard let manager else {
            onState?(false, "Bluetooth receiver could not be initialized.")
            return
        }
        guard manager.state == .poweredOn else { return }
        guard !servicePublished, !serviceAdding else { return }
        let reading = CBMutableCharacteristic(
            type: Self.readingID,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: Self.serviceID, primary: true)
        service.characteristics = [reading]
        serviceAdding = true
        manager.add(service)
    }

    func stop() {
        manager?.stopAdvertising()
        manager?.removeAllServices()
        servicePublished = false
        serviceAdding = false
        assembly = nil
        onState?(false, "Health receiver stopped.")
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            start()
        case .poweredOff:
            onState?(false, "Turn on Bluetooth to start the watch receiver.")
        case .unauthorized:
            onState?(false, "Allow Bluetooth access for AeroLink in iPhone Settings.")
        case .unsupported:
            onState?(false, "This iPhone cannot act as a Bluetooth receiver.")
        case .resetting, .unknown:
            onState?(false, "Bluetooth is starting. Try again in a moment.")
        @unknown default:
            onState?(false, "Bluetooth is unavailable. Check iPhone Bluetooth settings.")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        serviceAdding = false
        if let error {
            onState?(false, "Could not publish the activity receiver: \(error.localizedDescription)")
            return
        }
        servicePublished = true
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.serviceID]])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            onState?(false, "Could not advertise the health receiver: \(error.localizedDescription)")
        } else {
            onState?(true, "Health receiver is advertising for the watch.")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == Self.readingID,
                  let data = request.value,
                  data.count > 5,
                  data.count <= 20 else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }
            let version = data[0]
            let messageID = UInt16(data[1]) << 8 | UInt16(data[2])
            let index = Int(data[3])
            let count = Int(data[4])
            guard version == 1, count > 0, count <= 40, index < count else {
                assembly = nil
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }
            if index == 0 {
                assembly = Assembly(messageID: messageID, count: count, nextIndex: 0, bytes: Data())
            }
            guard var current = assembly,
                  current.messageID == messageID,
                  current.count == count,
                  current.nextIndex == index else {
                assembly = nil
                peripheral.respond(to: request, withResult: .unlikelyError)
                continue
            }
            current.bytes.append(data.dropFirst(5))
            current.nextIndex += 1
            guard current.bytes.count <= 512 else {
                assembly = nil
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }
            if current.nextIndex < count {
                assembly = current
                peripheral.respond(to: request, withResult: .success)
                continue
            }
            assembly = nil
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .millisecondsSince1970
                let reading = try decoder.decode(HealthReading.self, from: current.bytes)
                onReading(reading) { [weak peripheral] saved in
                    DispatchQueue.main.async {
                        peripheral?.respond(to: request, withResult: saved ? .success : .unlikelyError)
                    }
                }
            } catch {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
            }
        }
    }
}
