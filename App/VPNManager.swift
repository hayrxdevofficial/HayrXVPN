import Foundation
import NetworkExtension
import Combine

@MainActor
final class VPNManager: ObservableObject {

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var statusText = "Отключено"

    private var manager: NETunnelProviderManager?

    func prepare() {
        Task {
            await loadOrCreateManager()
            observeStatus()
        }
    }

    func toggle() {
        isConnected ? stop() : start()
    }

    func start() {
        Task {
            if manager == nil {
                await loadOrCreateManager()
            }

            guard let manager else {
                statusText = "Профиль не создан"
                return
            }

            manager.isEnabled = true
            do {
                try manager.saveToPreferences()
            } catch {
                statusText = "Ошибка сохранения: \(error.localizedDescription)"
                return
            }

            do {
                let options: [String: NSObject] = [
                    "vlessURL": VPNConstants.vlessURL as NSString
                ]
                try manager.connection.startVPNTunnel(options: options)
                isConnecting = true
                statusText = "Подключение..."
            } catch {
                statusText = "Ошибка запуска: \(error.localizedDescription)"
                isConnected = false
                isConnecting = false
            }
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
        statusText = "Отключение..."
    }

    private func loadOrCreateManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()

            if let existing = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == VPNConstants.tunnelBundleIdentifier
            }) {
                self.manager = existing
                return
            }

            let newManager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = VPNConstants.tunnelBundleIdentifier
            proto.serverAddress = VPNConstants.vpnDescription

            newManager.protocolConfiguration = proto
            newManager.localizedDescription = VPNConstants.vpnDescription
            newManager.isEnabled = true

            try await newManager.saveToPreferences()
            try await newManager.loadFromPreferences()

            self.manager = newManager
        } catch {
            statusText = "Ошибка инициализации: \(error.localizedDescription)"
        }
    }

    private func observeStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let self,
                let connection = note.object as? NEVPNConnection
            else { return }

            switch connection.status {
            case .connected:
                self.isConnected = true
                self.isConnecting = false
                self.statusText = "Подключено"
            case .connecting:
                self.isConnected = false
                self.isConnecting = true
                self.statusText = "Подключение..."
            case .disconnecting:
                self.isConnecting = false
                self.statusText = "Отключение..."
            case .disconnected:
                self.isConnected = false
                self.isConnecting = false
                self.statusText = "Отключено"
            case .invalid:
                self.statusText = "Не настроено"
            case .reasserting:
                self.statusText = "Переподключение..."
            @unknown default:
                break
            }
        }
    }
}
