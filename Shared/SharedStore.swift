import Foundation

/// Données partagées entre l'app et le widget (via un App Group).
enum SharedStore {
    static let groupID = "group.com.example.sommeiltracker"
    static let goalKey = "goalHours"
    static let lastAsleepKey = "lastAsleep"
    static let lastEndKey = "lastEnd"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    static var goalHours: Double {
        let v = defaults.double(forKey: goalKey)
        return v == 0 ? 8 : v
    }
}

/// 27000 s → "7 h 30"
func format(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    return String(format: "%d h %02d", minutes / 60, minutes % 60)
}
