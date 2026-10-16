import AppIntents

/// Action visible dans l'app Raccourcis : « Importer le sommeil » (Nébuleuse).
struct ImportSleepIntent: AppIntent {
    static var title: LocalizedStringResource = "Importer le sommeil"
    static var description = IntentDescription(
        "Envoie à Nébuleuse les segments de sommeil lus dans Santé par un raccourci."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Données", description: "Une ligne par segment : début;fin;type")
    var data: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = SleepStore.shared.importText(data)
        return .result(value: result.summary)
    }
}
