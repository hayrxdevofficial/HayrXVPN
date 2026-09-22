import NetworkExtension
import Combine

class VPNManager: ObservableObject {
    @Published var isConnected = false
    @Published var statusText = "Отключено"

    private var manager: NETunnelProviderManager?

    init() {
        loadManager()
    }

    private func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let existing = managers?.first {
                self.manager = existing
            } else {
                self.createManager()
            }
            self.observeStatus()
        }
    }

    private func createManager() {
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()

        // !!! Должно совпадать с Bundle ID расширения
        proto.providerBundleIdentifier = VPNConstants.tunnelBundleIdentifier
        proto.serverAddress = VPNConstants.vpnDescription

        manager.protocolConfiguration = proto
        manager.localizedDescription = VPNConstants.vpnDescription
        manager.isEnabled = true

        manager.saveToPreferences { error in
            if let error = error {
                print("Save error: \(error)")
            }
        }
        self.manager = manager
    }

    func start() {
        guard let manager = manager else { return }
        do {
            // Передаем VLESS-ссылку в расширение через опции
            let options: [String: NSObject] = ["vlessURL": VPNConstants.vlessURL as NSString]
            try manager.connection.startVPNTunnel(options: options)
            statusText = "Подключение..."
        } catch {
            statusText = "Ошибка: \(error.localizedDescription)"
            isConnected = false
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
        statusText = "Отключено"
    }

    private func observeStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager?.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let conn = self.manager?.connection else { return }
            switch conn.status {
            case .connected:
                self.isConnected = true
                self.statusText = "Подключено"
            case .connecting:
                self.statusText = "Подключение..."
            case .disconnecting:
                self.statusText = "Отключение..."
            case .disconnected, .invalid:
                self.isConnected = false
                self.statusText = "Отключено"
            default:
                break
            }
        }
    }
}
