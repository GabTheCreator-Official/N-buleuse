import WidgetKit
import SwiftUI

struct SleepEntry: TimelineEntry {
    let date: Date
    let asleep: TimeInterval
    let goalHours: Double
    let hasData: Bool
}

struct SleepProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepEntry {
        SleepEntry(date: .now, asleep: 7.5 * 3600, goalHours: 8, hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> SleepEntry {
        let d = SharedStore.defaults
        let asleep = d.double(forKey: SharedStore.lastAsleepKey)
        return SleepEntry(
            date: .now,
            asleep: asleep,
            goalHours: SharedStore.goalHours,
            hasData: asleep > 0
        )
    }
}

struct SleepWidgetView: View {
    let entry: SleepEntry

    private var progress: Double {
        guard entry.hasData else { return 0 }
        return min(entry.asleep / (entry.goalHours * 3600), 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.indigo.opacity(0.25), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(entry.hasData ? format(entry.asleep) : "—")
                    .font(.system(.callout, design: .rounded).bold())
                    .minimumScaleFactor(0.7)
            }
            .padding(4)
            Text("Objectif \(format(entry.goalHours * 3600))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct SleepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SleepWidget", provider: SleepProvider()) { entry in
            SleepWidgetView(entry: entry)
        }
        .configurationDisplayName("Nébuleuse")
        .description("Durée de la dernière nuit et progression vers votre objectif.")
        .supportedFamilies([.systemSmall])
    }
}
