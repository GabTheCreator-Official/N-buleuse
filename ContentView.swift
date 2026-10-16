import SwiftUI
import Charts
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SharedStore.goalKey, store: SharedStore.defaults) private var goalHours: Double = 8
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.nights.isEmpty {
                    emptyState
                } else {
                    nightsList
                }
            }
            .navigationTitle("Nébuleuse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        importFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Importer depuis le presse-papiers")
                }
            }
        }
        .onChange(of: goalHours) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        .alert("Import", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            importMessage = "Le presse-papiers est vide. Lancez d'abord le raccourci qui copie votre sommeil."
            return
        }
        importMessage = store.importText(text).summary
    }

    // MARK: - États

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
            Text("Aucune nuit importée")
                .font(.headline)
            Text("Lancez le raccourci qui lit votre sommeil dans Santé (voir le README), puis touchez le bouton ci-dessous si les données ont été copiées dans le presse-papiers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Coller depuis le presse-papiers") {
                importFromClipboard()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var nightsList: some View {
        let stats = SleepStats(nights: store.nights, goalHours: goalHours)
        return List {
            if let last = store.nights.first {
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
                ForEach(store.nights) { night in
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
        let recent = Array(store.nights.prefix(7).reversed())
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
                Text("Durée uniquement : cette nuit ne contient pas de phases de sommeil.")
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
