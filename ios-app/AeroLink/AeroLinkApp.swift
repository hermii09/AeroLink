import SwiftUI

@main
struct AeroLinkApp: App {
    @StateObject private var model = CompanionModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
