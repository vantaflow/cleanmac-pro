import SwiftUI
import AppKit
import Combine
import UserNotifications
import CleanCore

// "X a été supprimée — elle a laissé N Go": prompt shown when the user removes an
// app by hand and files remain in ~/Library. Detection lives in CleanCore
// (`AppRemovalWatcher`); this file owns the floating panel, the notification and
// the on/off setting.

private enum PromptColors {
    static let background = Color.adaptive(0x151922, 0xFFFFFF)
    static let border = Color.adaptive(0x2C3240, 0xC9CED9)
    static let text = Color.adaptive(0xF2F4F8, 0x14161B)
    static let muted = Color.adaptive(0xA9B0BE, 0x565D6C)
    static let faint = Color.adaptive(0x8A91A1, 0x7C8394)
    static let row = Color.adaptive(0xC4CAD6, 0x3A404D)
    static let listBorder = Color.adaptive(0x232733, 0xDCDFE7)
    static let listFill = Color.adaptive(0x12151C, 0xF4F5F8)
    static let accent = Accent.violet.color
    static let onAccent = Color.adaptive(0x160B33, 0xFFFFFF)
    static let tile = Color.adaptive(0x3B2A6B, 0xEBE5FF)
    static let tileText = Color.adaptive(0xD9CCFF, 0x5F41CC)
}

// MARK: - Model

@MainActor
final class RemovalPromptModel: ObservableObject {
    enum Phase: Equatable { case asking, deleting, done(String), failed(String) }

    let event: AppRemovalEvent
    let icon: NSImage?
    @Published var expanded = true
    @Published var phase: Phase = .asking

    var onFinish: (() -> Void)?

    init(event: AppRemovalEvent, icon: NSImage?) {
        self.event = event
        self.icon = icon
    }

    var sizeText: String { ByteFormatter.string(event.totalSize) }

    func ignoreOnce() { onFinish?() }

    func alwaysIgnore() {
        AppState.shared.addExclusion(appID: event.bundleID)
        onFinish?()
    }

    func deleteAll() {
        guard phase == .asking else { return }
        phase = .deleting
        let items = event.items
        Task.detached(priority: .userInitiated) { [weak self] in
            // Permanent, like the Uninstaller: nothing lingers in the Trash.
            var report = Cleaner.delete(items: items)
            var freed = report.freedBytes
            var removed = report.removedCount
            var failed = report.failedItems
            if !failed.isEmpty {
                let retry = items.filter { failed.contains($0.url) }
                let admin = Cleaner.deleteWithAdmin(items: retry)
                freed += admin.freedBytes
                removed += admin.removedCount
                failed = admin.failedItems
            }
            report = CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed)
            let final = report
            await MainActor.run { [weak self] in self?.finishDeletion(final) }
        }
    }

    private func finishDeletion(_ report: CleanReport) {
        AppState.shared.recordPermanentRemoval(report)
        Task { await ScanCache.shared.invalidate() }
        if report.failedItems.isEmpty {
            phase = .done(L("Libéré \(ByteFormatter.string(report.freedBytes))"))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                self?.onFinish?()
            }
        } else {
            phase = .failed(L("Impossible de supprimer \(report.failedItems.count) élément(s)"))
        }
    }
}

// MARK: - View

struct RemovalPromptView: View {
    @ObservedObject var model: RemovalPromptModel

    static let width: CGFloat = 520
    static func height(expanded: Bool) -> CGFloat { expanded ? 440 : 250 }

    private func shortPath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private var title: String { L("\(model.event.appName) a été supprimée") }

    private var subtitle: AttributedString {
        let md = L("Elle a laissé **\(model.sizeText)** de fichiers sur votre Mac.")
        return (try? AttributedString(markdown: md)) ?? AttributedString(md)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                iconView
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 18, weight: .semibold)).foregroundColor(PromptColors.text)
                    Text(subtitle).font(.system(size: 13.5)).foregroundColor(PromptColors.muted)
                }
                Spacer(minLength: 0)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { model.expanded.toggle() }
            } label: {
                HStack {
                    Text(model.expanded ? L("Masquer les \(model.event.items.count) éléments")
                                        : L("Voir les \(model.event.items.count) éléments"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: model.expanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(PromptColors.row)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(PromptColors.listFill))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PromptColors.listBorder))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.expanded ? L("Masquer les détails") : L("Afficher les détails"))

            if model.expanded {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.event.items.sorted { $0.size > $1.size }) { it in
                            HStack(spacing: 12) {
                                Text(shortPath(it.url))
                                    .lineLimit(1).truncationMode(.middle)
                                    .foregroundColor(PromptColors.row)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(ByteFormatter.string(it.size))
                                    .fontWeight(.semibold).monospacedDigit()
                                    .foregroundColor(PromptColors.text)
                            }
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            Divider().overlay(PromptColors.listBorder)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PromptColors.listBorder))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(PromptColors.background))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(PromptColors.border))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var iconView: some View {
        if let icon = model.icon {
            Image(nsImage: icon).resizable().interpolation(.high).frame(width: 52, height: 52)
        } else {
            Text(String(model.event.appName.prefix(1)).uppercased())
                .font(.system(size: 22, weight: .bold)).foregroundColor(PromptColors.tileText)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 13).fill(PromptColors.tile))
        }
    }

    @ViewBuilder private var footer: some View {
        switch model.phase {
        case .asking:
            HStack(spacing: 10) {
                Button(L("Toujours ignorer \(model.event.appName)")) { model.alwaysIgnore() }
                    .buttonStyle(.plain).font(.system(size: 13)).foregroundColor(PromptColors.faint)
                    .lineLimit(1)
                Spacer()
                Button(L("Ignorer")) { model.ignoreOnce() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(PromptColors.text)
                    .padding(.horizontal, 16).frame(height: 40)
                    .capsuleBorder(PromptColors.border, lineWidth: 1)
                Button(L("Supprimer \(model.sizeText)")) { model.deleteAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(PromptColors.onAccent)
                    .padding(.horizontal, 20).frame(height: 40)
                    .background(Capsule().fill(PromptColors.accent))
                    .keyboardShortcut(.defaultAction)
            }
        case .deleting:
            HStack(spacing: 10) {
                Spacer()
                ProgressView().controlSize(.small)
                Text(L("Suppression…")).font(.system(size: 14)).foregroundColor(PromptColors.muted)
            }.frame(height: 40)
        case .done(let msg):
            HStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundColor(PromptColors.accent)
                Text(msg).font(.system(size: 14, weight: .semibold)).foregroundColor(PromptColors.text)
            }.frame(height: 40)
        case .failed(let msg):
            HStack(spacing: 10) {
                Text(msg).font(.system(size: 13)).foregroundColor(Color.orange)
                Spacer()
                Button(L("Fermer")) { model.ignoreOnce() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(PromptColors.text)
                    .padding(.horizontal, 16).frame(height: 40)
                    .capsuleBorder(PromptColors.border, lineWidth: 1)
            }
        }
    }
}

// MARK: - Panel

private final class PromptPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class RemovalPromptPresenter {
    private var panel: NSPanel?
    private var model: RemovalPromptModel?
    private var sub: AnyCancellable?
    private var queue: [(AppRemovalEvent, NSImage?)] = []
    var currentPanel: NSPanel? { panel }
    var currentModel: RemovalPromptModel? { model }

    func present(_ event: AppRemovalEvent, icon: NSImage?) {
        if panel != nil { queue.append((event, icon)); return }
        let m = RemovalPromptModel(event: event, icon: icon)
        let host = NSHostingView(rootView: RemovalPromptView(model: m))
        let size = NSSize(width: RemovalPromptView.width, height: RemovalPromptView.height(expanded: m.expanded))
        let p = PromptPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                            backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = host
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: vf.maxX - size.width - 16, y: vf.maxY - size.height - 16))
        }
        m.onFinish = { [weak self] in self?.dismiss() }
        sub = m.$expanded.dropFirst().sink { [weak self] expanded in self?.resize(expanded: expanded) }
        model = m
        panel = p
        p.orderFrontRegardless()
    }

    private func resize(expanded: Bool) {
        guard let p = panel else { return }
        let h = RemovalPromptView.height(expanded: expanded)
        var f = p.frame
        f.origin.y += f.height - h          // keep the top edge fixed
        f.size.height = h
        p.setFrame(f, display: true, animate: true)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        model = nil
        sub = nil
        if !queue.isEmpty {
            let next = queue.removeFirst()
            present(next.0, icon: next.1)
        }
    }
}

// MARK: - Coordinator (setting + watcher + notification)

@MainActor
final class AppRemovalCoordinator: ObservableObject {
    static let shared = AppRemovalCoordinator()
    private static let key = "ai.turkeycode.cleanmacpro.watchAppRemoval"

    /// On by default.
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.key)
            apply()
        }
    }

    private var watcher: AppRemovalWatcher?
    private let presenter = RemovalPromptPresenter()
    private var icons: [String: NSImage] = [:]       // app path -> icon cached while the app existed
    private var started = false
    private var activeObserver: NSObjectProtocol?

    private init() {
        enabled = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
    }

    /// Call once at launch (the app lives in the menu bar, so this keeps running).
    func start() {
        guard !started else { return }
        started = true
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.cacheIcons() } }
        apply()
    }

    private func apply() {
        guard started else { return }
        if enabled {
            guard watcher == nil else { return }
            cacheIcons()
            // The saved index lets an app deleted while CleanMac Pro was closed be noticed at
            // the next launch. UI test runs never touch it.
            let state = UITestDriver.isEnabled ? nil
                : FS.home.appendingPathComponent("Library/Application Support/CleanMac Pro/app-index.json")
            let w = AppRemovalWatcher(stateFile: state, exclusions: { ExclusionList.load() }) { [weak self] event in
                Task { @MainActor in self?.handle(event) }
            }
            w.start()
            watcher = w
        } else {
            watcher?.stop()
            watcher = nil
        }
    }

    /// Remember icons of installed apps: once the bundle is gone its icon is not readable any more.
    private func cacheIcons() {
        let known = Set(icons.keys)
        Task.detached(priority: .utility) { [weak self] in
            let apps = AppIndex.build(roots: [URL(fileURLWithPath: "/Applications"),
                                              FS.home.appendingPathComponent("Applications")]).apps
            for a in apps where !known.contains(a.path) {
                let path = a.path
                await MainActor.run { [weak self] in
                    if let flat = Self.flatten(NSWorkspace.shared.icon(forFile: path), side: 128) { self?.icons[path] = flat }
                }
            }
        }
    }

    nonisolated private static func flatten(_ img: NSImage, side: Int) -> NSImage? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        img.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: NSSize(width: side, height: side))
        out.addRepresentation(rep)
        return out
    }

    private func icon(for event: AppRemovalEvent) -> NSImage? {
        if let c = icons[event.appPath] { return c }
        let trashed = FS.home.appendingPathComponent(".Trash/\(URL(fileURLWithPath: event.appPath).lastPathComponent)").path
        for p in [event.appPath, trashed] where FileManager.default.fileExists(atPath: p) {
            return NSWorkspace.shared.icon(forFile: p)
        }
        return nil
    }

    func handle(_ event: AppRemovalEvent) {
        guard enabled else { return }
        presenter.present(event, icon: icon(for: event))
        if !NSApp.isActive { notify(event) }
    }

    private func notify(_ event: AppRemovalEvent) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "CleanMac Pro"
        content.body = L("\(event.appName) a été supprimée. Il reste \(ByteFormatter.string(event.totalSize)) de fichiers associés.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "cmp.removal.\(event.bundleID)", content: content, trigger: nil))
    }

    /// For the UI test driver: shows the prompt on a synthetic event.
    func presentForTesting(_ event: AppRemovalEvent) -> (NSPanel, RemovalPromptModel)? {
        presenter.present(event, icon: nil)
        guard let p = presenter.currentPanel, let m = presenter.currentModel else { return nil }
        return (p, m)
    }
}

// MARK: - Settings row

struct RemovalWatchSetting: View {
    @ObservedObject private var coordinator = AppRemovalCoordinator.shared

    var body: some View {
        Section {
            Toggle(L("Proposer de nettoyer les restes quand une app est supprimée"), isOn: $coordinator.enabled)
        } footer: {
            Text(L("CleanMac Pro surveille Applications et la Corbeille. Quand vous supprimez une app à la main, il vous propose d'effacer les fichiers qu'elle a laissés (suppression définitive, avec votre accord)."))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
}
