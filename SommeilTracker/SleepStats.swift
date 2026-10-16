import Foundation

/// Statistiques sur les 7 dernières nuits.
struct SleepStats {
    let sampleCount: Int
    let averageAsleep: TimeInterval
    let goalMetCount: Int
    /// 0 à 100 ; nil s'il y a moins de 3 nuits.
    let regularity: Int?
    /// Heure de coucher moyenne, ex. "23:40".
    let averageBedtime: String?

    init(nights: [SleepNight], goalHours: Double) {
        let recent = Array(nights.prefix(7))
        sampleCount = recent.count
        averageAsleep = recent.isEmpty
            ? 0 : recent.map(\.asleep).reduce(0, +) / Double(recent.count)
        goalMetCount = recent.filter { $0.asleep >= goalHours * 3600 }.count

        if recent.count >= 3 {
            // Minutes depuis 18 h pour le coucher, depuis 12 h pour le lever :
            // évite le saut autour de minuit.
            let bed = recent.map { Self.minutes($0.start, shiftHours: 18) }
            let wake = recent.map { Self.minutes($0.end, shiftHours: 12) }
            // Écart-type moyen de 90 min ou plus → score 0.
            let sd = (Self.stdDev(bed) + Self.stdDev(wake)) / 2
            regularity = max(0, min(100, Int((100 - sd * 100 / 90).rounded())))

            let meanBed = bed.reduce(0, +) / Double(bed.count)
            let clock = Int(meanBed + 18 * 60) % 1440
            averageBedtime = String(format: "%02d:%02d", clock / 60, clock % 60)
        } else {
            regularity = nil
            averageBedtime = nil
        }
    }

    private static func minutes(_ date: Date, shiftHours: Int) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return Double((m - shiftHours * 60 + 1440) % 1440)
    }

    private static func stdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}
