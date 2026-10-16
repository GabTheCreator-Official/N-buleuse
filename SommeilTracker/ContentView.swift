import SwiftUI
import Charts
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var health: HealthManager
    @AppStorage(SharedStore.goalKey, store: SharedStore.defaults) private var goalHours: Double = 8

    var body: some View {
        NavigationStack {
            Group {
                if health.nights.isEmpty {
                    emptyState
                } else {
                    nightsList
                }
            }
            .navigationTitle("Nébuleuse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await health.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(health.isLoading)
                }
            }
        }
        .task { await health.requestAccessAndLoad() }
        .onChange(of: goalHours) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - États

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
            if health.isLoading {
                ProgressView()
            } else {
                Text("Aucune nuit trouvée")
                    .font(.headline)
                Text("Activez le suivi du sommeil dans l'app Sommeil de votre Apple Watch, portez-la la nuit, puis autorisez l'accès dans Réglages › Santé › Accès aux données.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Autoriser / actualiser") {
                    Task { await health.requestAccessAndLoad() }
                }
                .buttonStyle(.borderedProminent)
            }
            if let error = health.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var nightsList: some View {
        let stats = SleepStats(nights: health.nights, goalHours: goalHours)
        return List {
            if let last = health.nights.first {
                Section("Dernière nuit") {
                    NightCard(night: last, goalHours: goalHours)
                }
            }

            Section("Objectif") {
                Stepper(value: $goalHours, in: 5...11, step: 0.25) {
                    Text("Objectif : \(format(goalHours * 3600))")
                }
            }

            Section("7 dernières nuits") {
                statRow("Moyenne", format(stats.averageAsleep))
                statRow("Objectif atteint", "\(stats.goalMetCount) / \(stats.sampleCount)")
                if let score = stats.regularity {
                    statRow("Régularité", "\(score) / 100")
                }
                if let bed = stats.averageBedtime {
                    statRow("Coucher moyen", bed)
                }
                weeklyChart
            }

            Section("Historique") {
                ForEach(health.nights) { night in
                    HStack {
                        Text(night.end.formatted(.dateTime.weekday(.abbreviated).day().month()))
                        Spacer()
                        Text(format(night.asleep)).monospacedDigit()
                    }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private var weeklyChart: some View {
        let recent = Array(health.nights.prefix(7).reversed())
        return Chart {
            ForEach(recent) { night in
                BarMark(
                    x: .value("Jour", night.end, unit: .day),
                    y: .value("Heures", night.asleep / 3600)
                )
                .foregroundStyle(night.asleep >= goalHours * 3600 ? Color.indigo : Color.indigo.opacity(0.45))
            }
            RuleMark(y: .value("Objectif", goalHours))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.orange)
        }
        .chartYAxisLabel("h")
        .frame(height: 160)
    }
}

// MARK: - Carte d'une nuit

struct NightCard: View {
    let night: SleepNight
    let goalHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.indigo.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(night.asleep / (goalHours * 3600), 1))
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(min(night.asleep / (goalHours * 3600), 9.99) * 100)) %")
                        .font(.caption.bold())
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(format(night.asleep))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("\(night.start.formatted(date: .omitted, time: .shortened)) → \(night.end.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if night.hasStages {
                stagesBar
                HStack {
                    legend("Profond", night.deep, .indigo)
                    legend("Léger", night.core, .blue)
                    legend("Paradoxal", night.rem, .cyan)
                    legend("Éveil", night.awake, .orange)
                }
            } else {
                Text("Durée uniquement : cette montre ou cette version de watchOS n'enregistre pas les phases de sommeil.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var stagesBar: some View {
        let total = max(night.deep + night.core + night.rem + night.awake, 1)
        return GeometryReader { geo in
            HStack(spacing: 2) {
                segment(night.deep, total, geo.size.width, .indigo)
                segment(night.core, total, geo.size.width, .blue)
                segment(night.rem, total, geo.size.width, .cyan)
                segment(night.awake, total, geo.size.width, .orange)
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
    }

    private func segment(_ value: TimeInterval, _ total: TimeInterval, _ width: CGFloat, _ color: Color) -> some View {
        color.frame(width: max(width * value / total - 2, 0))
    }

    private func legend(_ name: String, _ value: TimeInterval, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name).font(.caption2).foregroundStyle(.secondary)
            }
            Text(format(value)).font(.caption).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
