import GameController
import IOKit.ps
import Network
import Observation

struct BatteryLevel: Equatable {
    let fraction: Double
    let isCharging: Bool
}

/// What the status icons show: whether a controller is connected, Wi-Fi and the Mac's battery.
@MainActor @Observable
final class SystemStatus {
    private(set) var isControllerConnected = false
    private(set) var isWiFiConnected = false
    private(set) var battery: BatteryLevel?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private var batteryTask: Task<Void, Never>?

    func start() {
        guard observers.isEmpty else { return }
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateController() }
            })
        }
        updateController()

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied && path.usesInterfaceType(.wifi)
            Task { @MainActor in self?.isWiFiConnected = connected }
        }
        pathMonitor.start(queue: .main)

        batteryTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.battery = Self.readBattery()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func updateController() {
        isControllerConnected = GCController.controllers().contains { $0.extendedGamepad != nil }
    }

    /// The internal battery's level, or nil on a Mac without one.
    private static func readBattery() -> BatteryLevel? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            let charging = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return BatteryLevel(fraction: min(Double(current) / Double(maximum), 1), isCharging: charging)
        }
        return nil
    }
}
