import SwiftUI

@main
struct KZSCMacOSApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1200, minHeight: 780)
        }
    }
}
