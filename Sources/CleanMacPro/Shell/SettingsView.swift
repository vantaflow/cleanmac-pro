import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CleanCore

/// Réglages (⌘,) : planification, exclusions, historique.
struct SettingsView: View {
    var body: some View {
        TabView {
            ScheduleSettings()
                .tabItem { Label(L("Planification"), systemImage: "clock.arrow.circlepath") }
            ExclusionsSettings()
                .tabItem { Label(L("Exclusions"), systemImage: "nosign") }
            HistorySettings()
                .tabItem { Label(L("Historique"), systemImage: "clock") }
        }
        .frame(width: 560, height: 420)
    }
}

private struct ScheduleSettings: View {
    @EnvironmentObject var appState: AppState

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: appState.schedule.hour, minute: appState.schedule.minute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { d in
                var s = appState.schedule
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                s.hour = c.hour ?? 9; s.minute = c.minute ?? 0
                appState.setSchedule(s)
            })
    }
    private let days = [L("Lundi"), L("Mardi"), L("Mercredi"), L("Jeudi"), L("Vendredi"), L("Samedi"), L("Dimanche")]

    var body: some View {
        Form {
            Section {
                Picker(L("Fréquence"), selection: Binding(
                    get: { appState.schedule.frequency },
                    set: { f in var s = appState.schedule; s.frequency = f; appState.setSchedule(s) })) {
                    ForEach(ScheduleFrequency.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                if appState.schedule.frequency != .off {
                    if appState.schedule.frequency == .weekly {
                        Picker(L("Jour"), selection: Binding(
                            get: { appState.schedule.weekday },
                            set: { d in var s = appState.schedule; s.weekday = d; appState.setSchedule(s) })) {
                            ForEach(1...7, id: \.self) { Text(days[$0 - 1]).tag($0) }
                        }
                    }
                    DatePicker(L("Heure"), selection: time, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text(L("Un LaunchAgent lance CleanMac Pro en arrière-plan à l'heure choisie : scan silencieux (Fichiers inutiles, Volumineux & doublons, Développeur), puis notification « X Go récupérables ». Rien n'est supprimé."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ExclusionsSettings: View {
    @EnvironmentObject var appState: AppState
    @State private var newAppID = ""

    var body: some View {
        Form {
            Section(L("Chemins ignorés")) {
                if appState.exclusions.paths.isEmpty { Text(L("Aucun")).foregroundStyle(.secondary) }
                ForEach(appState.exclusions.paths, id: \.self) { p in
                    HStack {
                        Text(p).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(L("Retirer")) { appState.removeExclusion(path: p) }
                    }
                }
                Button(L("Ajouter un dossier ou un fichier…")) { pick() }
            }
            Section(L("Apps ignorées (identifiant)")) {
                if appState.exclusions.appIDs.isEmpty { Text(L("Aucune")).foregroundStyle(.secondary) }
                ForEach(appState.exclusions.appIDs, id: \.self) { id in
                    HStack {
                        Text(id)
                        Spacer()
                        Button(L("Retirer")) { appState.removeExclusion(appID: id) }
                    }
                }
                HStack {
                    TextField("com.exemple.app", text: $newAppID)
                    Button(L("Ajouter")) {
                        appState.addExclusion(appID: newAppID)
                        newAppID = ""
                    }
                    .disabled(newAppID.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(L("Choisir une app…")) { pickApp() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = L("Ne plus proposer")
        if panel.runModal() == .OK { panel.urls.forEach { appState.addExclusion(path: $0.path) } }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url, let id = ExclusionList.bundleID(ofAppAt: url) {
            appState.addExclusion(appID: id)
        }
    }
}

private struct HistorySettings: View {
    @EnvironmentObject var appState: AppState
    @State private var message: String?

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.languageCode)
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func moduleTitle(_ raw: String) -> String { ModuleID(rawValue: raw)?.railTitle ?? raw }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Total libéré : \(ByteFormatter.string(appState.history.totalFreedBytes))"))
                    .font(.headline)
                Spacer()
                Button(L("Effacer l'historique")) { appState.clearHistory() }
                    .disabled(appState.history.entries.isEmpty)
            }
            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
            if appState.history.entries.isEmpty {
                Spacer()
                Text(L("Aucun nettoyage enregistré pour l'instant."))
                    .frame(maxWidth: .infinity).foregroundStyle(.secondary)
                Spacer()
            } else {
                List(appState.history.entries) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moduleTitle(e.module)).fontWeight(.semibold)
                            Text(L("\(Self.dateFormat.string(from: e.date)) · \(e.itemCount) élément(s) · \(ByteFormatter.string(e.freedBytes))"))
                                .font(.caption).foregroundStyle(.secondary)
                            if e.permanentCount > 0 {
                                Text(L("\(e.permanentCount) supprimé(s) définitivement : non restaurable(s)"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if e.canRestore {
                            Button(L("Restaurer")) { message = appState.restore(e).message }
                        }
                    }
                    .contextMenu {
                        Button(L("Supprimer de l'historique")) { appState.removeHistoryEntry(e) }
                    }
                }
            }
        }
        .padding()
    }
}
