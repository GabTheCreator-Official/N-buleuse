import SwiftUI

@main
struct SommeilTrackerApp: App {
    @StateObject private var health = HealthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(health)
        }
    }
}
