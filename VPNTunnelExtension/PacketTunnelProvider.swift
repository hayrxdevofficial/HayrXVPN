import NetworkExtension
import SwiftyXrayKit
import Foundation

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var bridge: XrayBridge?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        setTunnelNetworkSettings(makeNetworkSettings()) { [weak self] error in
            guard let self else { return }

            if let error {
                completionHandler(error)
                return
            }

            do {
                try self.startXray(options: options)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    private func startXray(options: [String: NSObject]?) throws {
        let vlessURL = (options?["vlessURL"] as? String) ?? VPNConstants.vlessURL

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

        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // ✅ Создаём мост и запускаем Xray
        let bridge = XrayBridge(packetFlow: packetFlow)
        try bridge.start(
            config: .url(vlessURL),
            dataDir: dataDir,
            finalConfigPath: finalConfigURL,
            preset: .mobile
        )

        self.bridge = bridge
        NSLog("[HayrXVPN] Xray started successfully")
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        bridge?.stop()
        bridge = nil
        NSLog("[HayrXVPN] tunnel stopped, reason: \(reason.rawValue)")
        completionHandler()
    }

    private func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = []
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fd00::2"], networkPrefixLengths: [64])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.mtu = 1500

        return settings
    }
}
