import Foundation
import HealthKit
import WidgetKit

/// Une nuit de sommeil, reconstruite à partir des échantillons Apple Health.
struct SleepNight: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    var asleep: TimeInterval = 0   // temps réellement endormi (sans chevauchement)
    var core: TimeInterval = 0     // sommeil léger (watchOS 9+, Series 4+)
    var deep: TimeInterval = 0     // sommeil profond
    var rem: TimeInterval = 0      // sommeil paradoxal
    var awake: TimeInterval = 0    // éveillé pendant la nuit

    /// Les phases ne sont disponibles qu'avec watchOS 9 ou plus.
    var hasStages: Bool { core + deep + rem > 0 }
    var inBed: TimeInterval { end.timeIntervalSince(start) }
}

@MainActor
final class HealthManager: ObservableObject {
    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    @Published var nights: [SleepNight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Demande l'accès en lecture au sommeil, puis charge les données.
    func requestAccessAndLoad() async {
        guard isAvailable else {
            errorMessage = "Apple Santé n'est pas disponible sur cet appareil."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Charge les `days` derniers jours de sommeil.
    func load(days: Int = 30) async {
        guard isAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let start = Calendar.current.date(
            byAdding: .day, value: -days,
            to: Calendar.current.startOfDay(for: now)
        )!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            nights = buildNights(from: samples)
            errorMessage = nil
            publishToWidget()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Partage la dernière nuit avec le widget.
    private func publishToWidget() {
        if let last = nights.first {
            SharedStore.defaults.set(last.asleep, forKey: SharedStore.lastAsleepKey)
            SharedStore.defaults.set(last.end.timeIntervalSince1970, forKey: SharedStore.lastEndKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Regroupement en nuits

    private func buildNights(from samples: [HKCategorySample]) -> [SleepNight] {
        // On ignore "inBed" : on ne garde que les segments d'endormissement ou d'éveil.
        let relevant = samples.filter {
            guard let v = HKCategoryValueSleepAnalysis(rawValue: $0.value) else { return false }
            return v != .inBed
        }
        guard !relevant.isEmpty else { return [] }

        // Une nouvelle nuit commence quand l'écart avec la précédente dépasse 3 h.
        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        var lastEnd: Date?
        for s in relevant {
            if let le = lastEnd, s.startDate.timeIntervalSince(le) > 3 * 3600 {
                groups.append(current)
                current = []
            }
            current.append(s)
            lastEnd = max(lastEnd ?? s.endDate, s.endDate)
        }
        if !current.isEmpty { groups.append(current) }

        return groups.compactMap(makeNight).sorted { $0.end > $1.end }
    }

    private func makeNight(from group: [HKCategorySample]) -> SleepNight? {
        guard let first = group.map(\.startDate).min(),
              let last = group.map(\.endDate).max() else { return nil }

        var night = SleepNight(start: first, end: last)
        var asleepIntervals: [DateInterval] = []

        for s in group {
            let duration = s.endDate.timeIntervalSince(s.startDate)
            guard let value = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
            switch value {
            case .awake:
                night.awake += duration
            case .asleepCore:
                night.core += duration
                asleepIntervals.append(DateInterval(start: s.startDate, end: s.endDate))
            case .asleepDeep:
                night.deep += duration
                asleepIntervals.append(DateInterval(start: s.startDate, end: s.endDate))
            case .asleepREM:
                night.rem += duration
                asleepIntervals.append(DateInterval(start: s.startDate, end: s.endDate))
            default: // endormi sans détail (anciennes montres / anciennes versions)
                asleepIntervals.append(DateInterval(start: s.startDate, end: s.endDate))
            }
        }

        night.asleep = Self.unionDuration(of: asleepIntervals)
        // Ignore les micro-siestes de moins de 20 min.
        return night.asleep >= 20 * 60 ? night : nil
    }

    /// Durée totale d'une liste d'intervalles, sans compter deux fois les chevauchements
    /// (utile si plusieurs sources écrivent dans Santé).
    private static func unionDuration(of intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var currentEnd: Date?
        for i in sorted {
            if let ce = currentEnd, i.start < ce {
                if i.end > ce {
                    total += i.end.timeIntervalSince(ce)
                    currentEnd = i.end
                }
            } else {
                total += i.duration
                currentEnd = i.end
            }
        }
        return total
    }
}
