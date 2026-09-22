import NetworkExtension
import SwiftyXrayKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var bridge: XrayBridge?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // 1. Настройка сетевых параметров туннеля
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.168.1.1")
        
        let ipv4 = NEIPv4Settings(addresses: ["192.168.1.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self, error == nil else {
                completionHandler(error)
                return
            }
            
            // 2. Получаем VLESS-ссылку из опций
            guard let vlessURL = options?["vlessURL"] as? String else {
                completionHandler(NSError(domain: "HayrXVPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "VLESS URL not provided"]))
                return
            }
            
            // 3. Запускаем Xray с помощью SwiftyXrayKit
            do {
                try self.startXray(with: vlessURL)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
    
    private func startXray(with vlessURL: String) throws {
        // Получаем путь к App Group
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: VPNConstants.appGroup) else {
            throw NSError(domain: "HayrXVPN", code: -2, userInfo: [NSLocalizedDescriptionKey: "App Group container not available"])
        }
        
        // Пути для данных Xray
        let dataDir = containerURL.appendingPathComponent("XrayData")
        let finalConfigURL = containerURL.appendingPathComponent("final_config.json")
        
        // Создаем директорию, если не существует
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        
        // Инициализируем XrayBridge
        let bridge = XrayBridge(packetFlow: packetFlow)
        
        // Запускаем с VLESS-ссылкой (SwiftyXrayKit автоматически конвертирует её в JSON)
        try bridge.start(
            config: .url(vlessURL),
            dataDir: dataDir,
            finalConfigPath: finalConfigURL
        )
        
        self.bridge = bridge
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        bridge?.stop()
        bridge = nil
        completionHandler()
    }
}
