import SwiftUI

@main
struct SommeilTrackerApp: App {
    @StateObject private var store = SleepStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
