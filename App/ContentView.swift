import SwiftUI

struct ContentView: View {
    @StateObject private var vpnManager = VPNManager()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                // Твоя иконка. Убедись, что она добавлена в Assets.xcassets с именем "AppIcon"
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                Text("HayrXVPN")
                    .font(.largeTitle.bold())

                Toggle("Подключение", isOn: $vpnManager.isConnected)
                    .padding(.horizontal, 40)
                    .onChange(of: vpnManager.isConnected) { newValue in
                        newValue ? vpnManager.start() : vpnManager.stop()
                    }

                Text(vpnManager.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
