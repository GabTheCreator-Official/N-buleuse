import Foundation
import WidgetKit

// MARK: - Modèles

enum SleepKind: String, Codable {
    case inBed, asleep, core, deep, rem, awake

    /// Reconnaît le libellé envoyé par Raccourcis, en français ou en anglais.
    init?(label: String) {
        let s = label
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "Œ", with: "oe")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if s.contains("deep") || s.contains("profond") {
            self = .deep
        } else if s.contains("paradox") || s == "rem" || s.hasPrefix("rem ") || s.hasSuffix(" rem") {
            self = .rem
        } else if s.contains("core") || s.contains("coeur") || s.contains("leger") || s.contains("light") {
            self = .core
        } else if s.contains("awake") || s.contains("eveil") || s.contains("reveil") {
            self = .awake
        } else if s.contains("in bed") || s.contains("au lit") || s == "bed" {
            self = .inBed
        } else if s.contains("asleep") || s.contains("endormi") || s.contains("dormi") {
            self = .asleep
        } else {
            return nil
        }
    }
}

struct SleepSegment: Codable, Hashable {
    let start: Date
    let end: Date
    let kind: SleepKind
}

/// Une nuit de sommeil, reconstruite à partir des segments importés.
struct SleepNight: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    var asleep: TimeInterval = 0   // temps réellement endormi (sans chevauchement)
    var core: TimeInterval = 0     // sommeil léger
    var deep: TimeInterval = 0     // sommeil profond
    var rem: TimeInterval = 0      // sommeil paradoxal
    var awake: TimeInterval = 0    // éveillé pendant la nuit

    var hasStages: Bool { core + deep + rem > 0 }
    var inBed: TimeInterval { end.timeIntervalSince(start) }
}

struct ImportResult {
    let added: Int
    let skipped: Int
    let nights: Int

    var summary: String {
        var s = "\(added) segment(s) ajouté(s), \(nights) nuit(s) disponible(s)."
        if skipped > 0 {
            s += " \(skipped) ligne(s) ignorée(s) (format non reconnu)."
        }
        return s
    }
}

// MARK: - Stockage et import

/// Reçoit le sommeil envoyé par le raccourci (une ligne par segment : début;fin;type),
/// le conserve sur l'iPhone et reconstruit les nuits.
@MainActor
final class SleepStore: ObservableObject {
    static let shared = SleepStore()

    @Published private(set) var nights: [SleepNight] = []
    private var segments: Set<SleepSegment> = []

    init() {
        loadFromDisk()
        rebuild()
    }

    /// Relit le fichier (utile si l'import a eu lieu pendant que l'app était fermée).
    func reload() {
        loadFromDisk()
        rebuild()
    }

    @discardableResult
    func importText(_ text: String) -> ImportResult {
        var incoming: [SleepSegment] = []
        var skipped = 0

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let parts = line.components(separatedBy: ";")
            guard parts.count >= 3,
                  let start = Self.parseDate(parts[0]),
                  let end = Self.parseDate(parts[1]),
                  end > start,
                  let kind = SleepKind(label: parts[2...].joined(separator: ";"))
            else {
                skipped += 1
                continue
            }
            incoming.append(SleepSegment(start: start, end: end, kind: kind))
        }

        let before = segments.count
        segments.formUnion(incoming)
        let cutoff = Date().addingTimeInterval(-90 * 86400)
        segments = segments.filter { $0.end >= cutoff }
        let added = max(segments.count - before, 0)

        saveToDisk()
        rebuild()
        publishToWidget()
        return ImportResult(added: added, skipped: skipped, nights: nights.count)
    }

    // MARK: Dates

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoZone: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    /// ISO 8601 de préférence ; sinon tente de comprendre une date écrite en toutes lettres.
    static func parseDate(_ string: String) -> Date? {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = isoPlain.date(from: t) { return d }
        if let d = isoFraction.date(from: t) { return d }
        if let d = isoNoZone.date(from: t) { return d }
        let range = NSRange(t.startIndex..., in: t)
        return detector?.firstMatch(in: t, options: [], range: range)?.date
    }

    // MARK: Fichier

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("segments.json")
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let array = try? decoder.decode([SleepSegment].self, from: data) {
            segments = Set(array)
        }
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(Array(segments)) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    // MARK: Regroupement en nuits

    private func rebuild() {
        let relevant = segments
            .filter { $0.kind != .inBed }
            .sorted { $0.start < $1.start }

        // Une nouvelle nuit commence quand l'écart avec le segment précédent dépasse 3 h.
        var groups: [[SleepSegment]] = []
        var current: [SleepSegment] = []
        var lastEnd: Date?
        for s in relevant {
            if let le = lastEnd, s.start.timeIntervalSince(le) > 3 * 3600 {
                groups.append(current)
                current = []
            }
            current.append(s)
            lastEnd = max(lastEnd ?? s.end, s.end)
        }
        if !current.isEmpty { groups.append(current) }

        nights = groups.compactMap(makeNight).sorted { $0.end > $1.end }
    }

    private func makeNight(from group: [SleepSegment]) -> SleepNight? {
        guard let first = group.map(\.start).min(),
              let last = group.map(\.end).max() else { return nil }

        var night = SleepNight(start: first, end: last)
        var asleepIntervals: [DateInterval] = []

        for s in group {
            let duration = s.end.timeIntervalSince(s.start)
            let interval = DateInterval(start: s.start, end: s.end)
            switch s.kind {
            case .awake:
                night.awake += duration
            case .core:
                night.core += duration
                asleepIntervals.append(interval)
            case .deep:
                night.deep += duration
                asleepIntervals.append(interval)
            case .rem:
                night.rem += duration
                asleepIntervals.append(interval)
            case .asleep:
                asleepIntervals.append(interval)
            case .inBed:
                break
            }
        }

        night.asleep = Self.unionDuration(of: asleepIntervals)
        // Ignore les micro-siestes de moins de 20 min.
        return night.asleep >= 20 * 60 ? night : nil
    }

    /// Durée totale d'une liste d'intervalles, sans compter deux fois les chevauchements.
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

    // MARK: Widget

    private func publishToWidget() {
        if let last = nights.first {
            SharedStore.defaults.set(last.asleep, forKey: SharedStore.lastAsleepKey)
            SharedStore.defaults.set(last.end.timeIntervalSince1970, forKey: SharedStore.lastEndKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
