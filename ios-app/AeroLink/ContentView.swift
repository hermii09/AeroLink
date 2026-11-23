import SwiftUI

struct ContentView: View {
    @ObservedObject var model: CompanionModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.18, blue: 0.24), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("AeroLink").font(.largeTitle.bold())
                        Text("Your watch, connected.").foregroundStyle(.white.opacity(0.75))
                    }
                    card(title: "Apple Health", symbol: "heart.fill") {
                        Text("Choose to send steps and heart rate from your Galaxy Watch to Apple Health.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        Button(model.healthReady ? "Health setup complete" : "Set up Apple Health") {
                            Task { await model.enableHealthSync() }
                        }
                        .buttonStyle(AeroButtonStyle())
                        .disabled(model.healthReady)
                    }
                    card(title: "Watch connection", symbol: "applewatch") {
                        Label(model.receiverRunning ? "Receiver on" : "Receiver off", systemImage: model.receiverRunning ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                            .foregroundStyle(model.receiverRunning ? Color.mint : .white)
                        Button(model.receiverRunning ? "Stop receiver" : "Start watch receiver") {
                            model.receiverRunning ? model.stopReceiver() : model.startReceiver()
                        }
                        .buttonStyle(AeroButtonStyle())
                    }
                    Text(model.status)
                        .font(.footnote).foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 2)
                    Text("Health readings stay on your devices. AeroLink does not use a cloud account.")
                        .font(.caption).foregroundStyle(.white.opacity(0.55))
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func card<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(Color(red: 0.48, green: 0.9, blue: 0.95))
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.13)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.17))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LinearGradient(colors: [Color(red: 0.52, green: 0.94, blue: 0.96), Color(red: 0.42, green: 0.85, blue: 0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
