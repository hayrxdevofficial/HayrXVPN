import NetworkExtension
import SwiftyXrayKit
import Foundation

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // Мост между NEPacketTunnelFlow и Xray TUN
    private var bridge: XrayBridge?

    // MARK: - Start

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // 1. Сначала настраиваем сетевые параметры туннеля
        let settings = makeNetworkSettings()

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }

            if let error {
                completionHandler(error)
                return
            }

            // 2. Только после того как настройки применились — стартуем Xray
            do {
                try self.startXray(options: options)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    // MARK: - Stop

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        bridge?.stop()
        bridge = nil
        NSLog("[HayrXVPN] tunnel stopped, reason: \(reason.rawValue)")
        completionHandler()
    }

    // MARK: - Xray

    private func startXray(options: [String: NSObject]?) throws {
        // Достаём VLESS-ссылку, которую приложение передало через startVPNTunnel(options:)
        let vlessURL: String?
        if let fromOptions = options?["vlessURL"] as? String {
            vlessURL = fromOptions
        } else {
            vlessURL = VPNConstants.vlessURL   // fallback на константу
        }

        guard let vlessURL, !vlessURL.isEmpty else {
            throw NSError(
                domain: "HayrXVPN",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "VLESS URL не передан"]
            )
        }

        // Готовим директорию для данных Xray в App Group
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: VPNConstants.appGroup)
        else {
            throw NSError(
                domain: "HayrXVPN",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "App Group container недоступен"]
            )
        }

        let dataDir = containerURL.appendingPathComponent("XrayData", isDirectory: true)
        let finalConfigURL = containerURL.appendingPathComponent("final_config.json")

        try? FileManager.default.createDirectory(
            at: dataDir,
            withIntermediateDirectories: true
        )

        // Создаём мост и запускаем Xray с share-link
        let bridge = XrayBridge(packetFlow: packetFlow)

        try bridge.start(
            config: .url(vlessURL),
            dataDir: dataDir,
            finalConfigPath: finalConfigURL,
            preset: .mobile        // мобильный пресет для iOS: экономия памяти
        )

        self.bridge = bridge
        NSLog("[HayrXVPN] Xray started successfully")
    }

    // MARK: - Network settings

    private func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        // IPv4
        let ipv4 = NEIPv4Settings(
            addresses: ["10.0.0.2"],
            subnetMasks: ["255.255.255.0"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]   // весь трафик в туннель
        ipv4.excludedRoutes = []
        settings.ipv4Settings = ipv4

        // IPv6 (чтобы не было утечек через IPv6)
        let ipv6 = NEIPv6Settings(
            addresses: ["fd00::2"],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        // DNS
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        // MTU — 1500 хорошо для мобильных сетей; можно снизить до 1280, если проблемы
        settings.mtu = 1500

        return settings
    }
}