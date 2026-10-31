import SwiftUI
import CleanCore

/// Smart Care: home → analysis → results (one card per area, only what is
/// ticked and safe gets run) → cleanup running. The measured outcome is shown by
/// `ResultScreen`.
struct SmartScanScreen: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.smartCare.phase {
            case .home:     SmartCareHome()
            case .scanning: SmartCareScanning()
            case .results:  SmartCareResults()
            case .running:  SmartCareRunning()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: appState.smartCare.phase)
        .transition(.opacity)
    }
}

// MARK: — Home

private struct SmartCareHome: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private var firstName: String {
        let full = NSFullUserName().trimmingCharacters(in: .whitespaces)
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? NSUserName() : first
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.languageCode)
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        let dark = theme.dark
        VStack(spacing: 28) {
            HeroRing(symbol: "checkmark.shield", accent: .mint)
            VStack(spacing: 10) {
                Text(L("Bonjour, \(firstName)."))
                    .font(.system(size: 40, weight: .semibold)).tracking(-0.8)
                    .foregroundColor(.text1(dark))
                Text(L("Une analyse rapide passe en revue le nettoyage, la sécurité, les performances et vos applications. Rien n'est supprimé sans votre accord."))
                    .font(.system(size: 16)).lineSpacing(3)
                    .foregroundColor(.text2(dark))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
            HStack(spacing: 10) {
                chip(appState.lastSmartCareScan.map { L("Dernière analyse : \(Self.dateFormat.string(from: $0))") }
                     ?? L("Aucune analyse pour l'instant"))
                chip(L("\(ByteFormatter.string(appState.history.totalFreedBytes)) libérés au total"))
            }
            Btn(kind: .primary, size: .xl, label: L("Analyser mon Mac")) { appState.startSmartCare() }
                .padding(.top, 6)
                .accessibilityIdentifier("smartcare-analyze")
        }
        .padding(48)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13)).foregroundColor(.textSoft(theme.dark))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.inset(theme.dark)))
            .overlay(Capsule().strokeBorder(Color.cardBorder(theme.dark), lineWidth: 1))
    }
}

// MARK: — Scanning

private struct SmartCareScanning: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private func label(_ m: ModuleID) -> String {
        switch m {
        case .cleanup:     return L("Nettoyage")
        case .developer:   return L("Développeur")
        case .files:       return L("Encombrement")
        case .privacy:     return L("Confidentialité")
        case .security:    return L("Protection")
        case .performance: return L("Performances")
        case .updates:     return L("Applications")
        default:           return m.railTitle
        }
    }

    var body: some View {
        let dark = theme.dark
        VStack(spacing: 26) {
            HeroRing(symbol: "magnifyingglass", accent: .mint, progress: appState.smartCareProgress)
            VStack(spacing: 8) {
                Text(L("Analyse en cours…"))
                    .font(.system(size: 34, weight: .semibold)).tracking(-0.6)
                    .foregroundColor(.text1(dark))
                Text(verbatim: "\(Int(appState.smartCareProgress * 100)) %")
                    .font(.figure(18)).foregroundColor(.text2(dark))
            }
            FlowChips(items: AppState.smartCareModules.map { m in
                let s = appState.state(for: m)
                return ChipModel(id: m.rawValue, title: label(m), done: s.result != nil && !s.isScanning)
            })
            Btn(kind: .secondary, size: .lg, label: L("Arrêter")) { appState.cancelSmartCare() }
        }
        .padding(48)
    }
}

private struct ChipModel: Identifiable { let id: String; let title: String; let done: Bool }

private struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [ChipModel]

    var body: some View {
        let dark = theme.dark
        HStack(spacing: 8) {
            ForEach(items) { it in
                HStack(spacing: 6) {
                    Image(systemName: it.done ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 12))
                        .foregroundColor(it.done ? Accent.mint.color : Color.text3(dark))
                    Text(it.title).font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(it.done ? .text1(dark) : .text2(dark))
                        .lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.inset(dark)))
                .overlay(Capsule().strokeBorder(Color.cardBorder(dark), lineWidth: 1))
            }
        }
        .animation(.easeOut(duration: 0.25), value: items.map(\.done))
    }
}

// MARK: — Running

private struct SmartCareRunning: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 26) {
            HeroRing(symbol: "sparkles", accent: .mint, progress: appState.smartCare.runProgress)
            VStack(spacing: 8) {
                Text(L("Nettoyage en cours…"))
                    .font(.system(size: 34, weight: .semibold)).tracking(-0.6)
                    .foregroundColor(.text1(theme.dark))
                Text(appState.smartCare.runStatus)
                    .font(.system(size: 15)).foregroundColor(.text2(theme.dark))
                Text(L("Gardez l'app ouverte : l'espace libéré est mesuré à la fin."))
                    .font(.system(size: 13)).foregroundColor(.text3(theme.dark))
                    .padding(.top, 4)
            }
        }
        .padding(48)
    }
}

// MARK: — Results

private struct SmartCareResults: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        let plan = appState.smartCarePlan
        let dark = theme.dark
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(plan)
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            CleanupCard(plan: plan)
                            ProtectionCard(plan: plan)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            PerformanceCard(plan: plan)
                            ApplicationsCard(plan: plan)
                            ClutterCard(plan: plan)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 30).padding(.bottom, 16)
            }
            footer(plan)
                .background(Color.canvas(dark))
        }
    }

    private func attentionPoints(_ p: SmartCarePlan) -> Int {
        [!p.securityIssues.isEmpty, !p.updates.isEmpty, p.clutterBytes > 0, !p.performanceTasks.isEmpty]
            .filter { $0 }.count
    }

    private func header(_ p: SmartCarePlan) -> some View {
        let points = attentionPoints(p)
        let bytes = p.regenerableBytes
        let title: String
        if bytes > 0 {
            title = points > 0
                ? L("\(ByteFormatter.string(bytes)) à libérer, \(Int(points)) point(s) à vérifier")
                : L("\(ByteFormatter.string(bytes)) à libérer")
        } else {
            title = points > 0 ? L("\(Int(points)) point(s) à vérifier") : L("Votre Mac est impeccable")
        }
        let secs = Int(appState.smartCare.scanSeconds.rounded())
        return VStack(alignment: .leading, spacing: 6) {
            Text(L("Analyse terminée · \(Int(secs)) s"))
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Accent.mint.soft)
            Text(title)
                .font(.system(size: 32, weight: .semibold)).tracking(-0.6)
                .foregroundColor(.text1(theme.dark))
            Text(L("Seuls les éléments cochés seront traités. Vos fichiers personnels ne sont jamais inclus sans revue."))
                .font(.system(size: 15)).foregroundColor(.text2(theme.dark))
        }
    }

    private func footer(_ p: SmartCarePlan) -> some View {
        let dark = theme.dark
        let permanent = p.runnablePermanentBytes
        let toTrash = p.runnableTrashBytes
        let installs = appState.smartCare.includeUpdates ? p.installableUpdates.count : 0
        var parts: [String] = []
        if permanent > 0 { parts.append(L("libérer \(ByteFormatter.string(permanent))")) }
        if toTrash > 0 { parts.append(L("mettre \(ByteFormatter.string(toTrash)) à la Corbeille")) }
        if installs > 0 { parts.append(L("installer \(Int(installs)) mise(s) à jour")) }
        let summary = parts.isEmpty ? L("Rien de coché pour l'instant") : L("Prévu : ") + parts.joined(separator: " · ")
        let canRun = p.hasWork || installs > 0
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary).font(.system(size: 14, weight: .semibold)).foregroundColor(.text1(dark))
                if let d = appState.disk, permanent > 0 {
                    Text(L("Espace libre avant : \(ByteFormatter.string(d.freeBytes)) · après (estimé) : \(ByteFormatter.string(d.freeBytes + permanent))"))
                        .font(.system(size: 12.5)).foregroundColor(.text2(dark))
                } else if let d = appState.disk {
                    Text(L("Espace libre : \(ByteFormatter.string(d.freeBytes))"))
                        .font(.system(size: 12.5)).foregroundColor(.text2(dark))
                }
            }
            Spacer()
            Btn(kind: .ghost, size: .lg, label: L("Nouvelle analyse")) { appState.resetSmartCare() }
            Btn(kind: .primary, size: .lg, label: L("Lancer")) { appState.runSmartCare() }
                .disabled(!canRun)
                .accessibilityIdentifier("smartcare-run")
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .cardSurface(dark: dark)
        .padding(.horizontal, 40).padding(.bottom, 22).padding(.top, 4)
    }
}

// MARK: — Cards

/// Shared card chrome: icon tile, title, trailing control, big figure, text, link.
private struct CareCard<Trailing: View, Extra: View>: View {
    @Environment(\.theme) private var theme
    let category: SmartCareCategory
    let accent: Accent
    let symbol: String
    var big: String
    var text: String
    var linkLabel: String = L("Revoir les détails →")
    var secondLinkLabel: String? = nil
    var onSecondLink: (() -> Void)? = nil
    var border: Color? = nil
    var dashed: Bool = false
    /// Narrow cards: the trailing control sits on its own line under the title.
    var compact: Bool = false
    let onReview: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        let dark = theme.dark
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconChip(symbol: symbol, accent: accent, size: 34)
                Text(category.title).font(.system(size: 17, weight: .semibold)).foregroundColor(.text1(dark))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                if !compact { trailing() }
            }
            if compact { trailing() }
            Text(big).font(.figure(28, .bold)).tracking(-0.4).foregroundColor(.text1(dark))
                .lineLimit(2).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(text).font(.system(size: 13)).lineSpacing(2).foregroundColor(.text2(dark))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            extra()
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                Button(action: onReview) {
                    Text(linkLabel).font(.system(size: 13.5, weight: .semibold)).foregroundColor(accent.soft)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("review-\(category.rawValue)")
                if let secondLinkLabel, let onSecondLink {
                    Button(action: onSecondLink) {
                        Text(secondLinkLabel).font(.system(size: 13.5, weight: .semibold)).foregroundColor(accent.soft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface(dark: dark, border: border, dashed: dashed)
    }
}

private struct IncludeToggle: View {
    @Environment(\.theme) private var theme
    @Binding var isOn: Bool
    var mixed = false
    var accent: Accent
    var label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 13)).foregroundColor(.textSoft(theme.dark))
            CmpCheckbox(isOn: $isOn, mixed: mixed, accent: accent.color, label: label)
        }
    }
}

private struct CleanupCard: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let plan: SmartCarePlan

    private var included: Binding<Bool> {
        Binding(get: { plan.selectedRegenerableBytes > 0 },
                set: { appState.setCleanupIncluded($0) })
    }

    private var partial: Bool {
        plan.selectedRegenerableBytes > 0 && plan.selectedRegenerableBytes < plan.regenerableBytes
    }

    private var detail: String {
        var parts: [String] = []
        let cache = plan.regenerableBytes(kind: .cache, module: .cleanup)
        let temp = plan.regenerableBytes(kind: .tempFile, module: .cleanup)
        let logs = plan.regenerableBytes(kind: .log, module: .cleanup)
        if cache > 0 { parts.append(L("caches des apps \(ByteFormatter.string(cache))")) }
        if temp > 0 { parts.append(L("fichiers temporaires \(ByteFormatter.string(temp))")) }
        if logs > 0 { parts.append(L("journaux \(ByteFormatter.string(logs))")) }
        if plan.developerCacheBytes > 0 { parts.append(L("caches développeur \(ByteFormatter.string(plan.developerCacheBytes))")) }
        if parts.isEmpty { return L("Aucun cache, journal ni fichier temporaire à supprimer.") }
        let list = parts.joined(separator: " · ")
        return list.prefix(1).uppercased() + list.dropFirst() + ". " + L("Supprimés définitivement, ils se recréent si besoin.")
    }

    var body: some View {
        let on = plan.selectedRegenerableBytes > 0
        CareCard(category: .cleanup, accent: .mint, symbol: "sparkles",
                 big: plan.regenerableBytes > 0 ? ByteFormatter.string(plan.regenerableBytes) : L("Rien à nettoyer"),
                 text: partial ? detail + " " + L("Sélectionné : \(ByteFormatter.string(plan.selectedRegenerableBytes)).") : detail,
                 secondLinkLabel: plan.developerCacheBytes > 0 ? L("Voir les caches développeur →") : nil,
                 onSecondLink: { appState.review(.developer) },
                 border: on ? Accent.mint.color : nil,
                 onReview: { appState.review(.cleanup) },
                 trailing: {
                     if plan.regenerableBytes > 0 {
                         IncludeToggle(isOn: included, mixed: partial, accent: .mint, label: L("Inclure"))
                     } else {
                         StatusPill(status: .good, text: L("Impeccable"))
                     }
                 },
                 extra: {
                     VStack(alignment: .leading, spacing: 6) {
                         if plan.trashBytes > 0 {
                             HStack(spacing: 8) {
                                 CmpCheckbox(isOn: Binding(get: { plan.trashSelected },
                                                           set: { appState.setTrashIncluded($0) }),
                                             accent: Accent.mint.color, label: L("Vider aussi la Corbeille"))
                                 Text(L("Vider aussi la Corbeille (\(ByteFormatter.string(plan.trashBytes))) — irréversible"))
                                     .font(.system(size: 12.5)).foregroundColor(.textSoft(theme.dark))
                             }
                         }
                     }
                 })
    }
}

private struct ProtectionCard: View {
    @EnvironmentObject var appState: AppState
    let plan: SmartCarePlan

    private var text: String {
        var out: [String] = []
        let issues = plan.securityIssues
        if !issues.isEmpty {
            out.append(issues.prefix(3).map { "\($0.name) : \($0.detail ?? "")" }.joined(separator: " · ") + ".")
        }
        let ok = (appState.state(for: .security).result?.items ?? [])
            .filter { $0.kind == .securityFinding && $0.severity == .good && $0.group != L("Menaces") }
            .map(\.name)
        if !ok.isEmpty { out.append(L("\(ok.joined(separator: ", ")) : en ordre.")) }
        if appState.state(for: .security).result == nil { return L("Analyse de sécurité indisponible.") }
        return out.joined(separator: " ")
    }

    var body: some View {
        let threats = plan.threats.count
        let settings = plan.settingsToCheck.count
        CareCard(category: .protection, accent: .blue, symbol: "shield.lefthalf.filled",
                 big: settings > 0 ? L("\(Int(settings)) réglage(s)") : (threats > 0 ? L("\(Int(threats)) menace(s)") : L("Tout est en ordre")),
                 text: text,
                 onReview: { appState.review(.security) },
                 trailing: {
                     if threats > 0 { StatusPill(status: .bad, text: L("\(Int(threats)) menace(s)")) }
                     else { StatusPill(status: .info, text: L("Aucune menace")) }
                 },
                 extra: {
                     if plan.privacyBytes > 0 {
                         Button { appState.review(.privacy) } label: {
                             let n = plan.selectedPrivacy.count
                             Text(n > 0
                                  ? L("Navigateurs : \(Int(n)) élément(s) choisis → Corbeille")
                                  : L("Données de navigateurs \(ByteFormatter.string(plan.privacyBytes)) — à choisir vous-même →"))
                                 .font(.system(size: 12.5, weight: .medium)).foregroundColor(Accent.blue.soft)
                                 .multilineTextAlignment(.leading)
                         }.buttonStyle(.plain)
                     }
                 })
    }
}

private struct PerformanceCard: View {
    @EnvironmentObject var appState: AppState
    let plan: SmartCarePlan

    var body: some View {
        let tasks = plan.performanceTasks.filter { $0.kind != .processSnapshot }
        let names = tasks.prefix(4).map(\.name).joined(separator: ", ")
        CareCard(category: .performance, accent: .amber, symbol: "bolt.fill",
                 big: tasks.isEmpty ? L("Tout est fluide") : L("\(tasks.count) tâche(s) recommandée(s)"),
                 text: tasks.isEmpty
                     ? L("Aucun élément ne ralentit le démarrage de votre Mac.")
                     : L("S'ouvrent à chaque démarrage : \(names). Vous pouvez les désactiver depuis le module."),
                 compact: true,
                 onReview: { appState.review(.performance) },
                 trailing: {
                     if tasks.isEmpty { StatusPill(status: .good, text: L("Rien à faire")) }
                     else { StatusPill(status: .warn, text: L("À vérifier")) }
                 },
                 extra: { EmptyView() })
    }
}

private struct ApplicationsCard: View {
    @EnvironmentObject var appState: AppState
    let plan: SmartCarePlan

    private func count(_ prefix: String) -> Int { plan.updates.filter { ($0.group ?? "").hasPrefix(prefix) }.count }

    private var text: String {
        if plan.updates.isEmpty { return L("Toutes vos applications sont à jour.") }
        var parts: [String] = []
        let direct = count("Apps · Direct"), store = count("Apps · App Store")
        let brew = count("Homebrew"), mac = count("macOS")
        if direct > 0 { parts.append(L("\(Int(direct)) app(s) téléchargée(s)")) }
        if store > 0 { parts.append(L("\(Int(store)) app(s) de l'App Store")) }
        if brew > 0 { parts.append(L("\(Int(brew)) paquet(s) Homebrew")) }
        if mac > 0 { parts.append(L("\(Int(mac)) mise(s) à jour macOS")) }
        var s = parts.joined(separator: " · ") + "."
        let n = plan.installableUpdates.count
        if n > 0 { s += " " + L("\(Int(n)) peuvent s'installer d'ici (signature vérifiée).") }
        else { s += " " + L("À installer depuis leur source.") }
        return s
    }

    var body: some View {
        let n = plan.updates.count
        CareCard(category: .applications, accent: .violet, symbol: "square.grid.2x2.fill",
                 big: n == 0 ? L("Tout est à jour") : L("\(Int(n)) mise(s) à jour"),
                 text: text,
                 border: appState.smartCare.includeUpdates && !plan.installableUpdates.isEmpty ? Accent.violet.color : nil,
                 compact: true,
                 onReview: { appState.review(.updates) },
                 trailing: {
                     if !plan.installableUpdates.isEmpty {
                         IncludeToggle(isOn: Binding(get: { appState.smartCare.includeUpdates },
                                                     set: { appState.smartCare.includeUpdates = $0 }),
                                       accent: .violet, label: L("Mettre à jour"))
                     } else if n == 0 {
                         StatusPill(status: .good, text: L("À jour"))
                     } else {
                         StatusPill(status: .neutral, text: L("Manuel"))
                     }
                 },
                 extra: { EmptyView() })
    }
}

private struct ClutterCard: View {
    @EnvironmentObject var appState: AppState
    let plan: SmartCarePlan

    var body: some View {
        let sel = plan.selectedClutter
        let selBytes = sel.reduce(0) { $0 + $1.size }
        CareCard(category: .clutter, accent: .coral, symbol: "tray.full.fill",
                 big: plan.clutterBytes > 0 ? ByteFormatter.string(plan.clutterBytes) : L("Rien"),
                 text: sel.isEmpty
                     ? L("Gros fichiers, anciens fichiers et doublons. Jamais traités par « Lancer » : vous choisissez fichier par fichier.")
                     : L("\(sel.count) fichier(s) choisis (\(ByteFormatter.string(selBytes))) iront à la Corbeille avec « Lancer » : vous pourrez les restaurer."),
                 linkLabel: L("Choisir les fichiers →"),
                 border: sel.isEmpty ? Color(hex: 0x3A3F4C) : Accent.coral.color,
                 dashed: sel.isEmpty,
                 compact: true,
                 onReview: { appState.review(.files) },
                 trailing: {
                     if sel.isEmpty { StatusPill(status: .neutral, text: L("À revoir vous-même"), dot: false) }
                     else { StatusPill(status: .warn, text: L("\(sel.count) choisi(s)"), dot: false) }
                 },
                 extra: { EmptyView() })
    }
}
