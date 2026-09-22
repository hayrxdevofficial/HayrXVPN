import SwiftUI

struct ContentView: View {
    @StateObject private var vpn = VPNManager()

    // Фирменный фиолетовый из логотипа
    private let brandPurple = Color(red: 0.51, green: 0.20, blue: 0.92)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    brandPurple.opacity(0.25),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Заглушка вместо иконки — SF Symbol
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(brandPurple)
                        .shadow(color: brandPurple.opacity(0.6), radius: 20)

                    Image(systemName: "shield.lefthalf.filled")
                        .resizable()
                        .scaledToFit()
                        .padding(28)
                        .foregroundStyle(.white)
                }
                .frame(width: 150, height: 150)

                Text("HayrXVPN")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(vpn.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Button {
                    vpn.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(vpn.isConnected ? Color.green : brandPurple)
                            .shadow(
                                color: (vpn.isConnected ? Color.green : brandPurple).opacity(0.5),
                                radius: 20
                            )
                            .frame(width: 140, height: 140)

                        Image(systemName: "power")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                Text(vpn.isConnected ? "Нажмите, чтобы отключить" : "Нажмите, чтобы подключить")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()
            }
            .padding()
        }
        .onAppear {
            vpn.prepare()
        }
    }
}

#Preview {
    ContentView()
}