import Foundation
import SwiftUI
import CleanCore

@MainActor
final class AppState: ObservableObject {
    @Published var theme = Theme()
    @Published var active: ModuleID = .dashboard
    @Published var moduleStates: [ModuleID: ModuleState] = [:]
    @Published var menubarOpen = false

    init() {
        for m in ModuleID.allCases {
            moduleStates[m] = ModuleState()
        }
    }

    func state(for module: ModuleID) -> ModuleState {
        moduleStates[module] ?? ModuleState()
    }

    func update(_ module: ModuleID, _ transform: (inout ModuleState) -> Void) {
        var s = moduleStates[module] ?? ModuleState()
        transform(&s)
        moduleStates[module] = s
    }

    func scanner(for module: ModuleID) -> (any FileScanner)? {
        switch module {
        case .cleanup:     return CleanupScanner()
        case .files:       return LargeFilesScanner()
        case .uninstaller: return AppUninstaller()
        case .security:    return SecurityScanner()
        case .privacy:     return PrivacyScanner()
        case .updates:     return UpdatesScanner()
        case .performance: return PerformanceScanner()
        case .maintenance: return MaintenanceScanner()
        case .spaceLens:   return SpaceLensScanner()
        case .smartScan:   return CleanupScanner()  // Smart scan re-runs cleanup
        case .dashboard, .result: return nil
        }
    }

    func startScan(module: ModuleID) {
        guard let scanner = scanner(for: module) else { return }
        update(module) { s in
            s.isScanning = true
            s.progress = 0
            s.status = "Démarrage…"
            s.result = nil
            s.selection.removeAll()
        }
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try await scanner.scan(progress: { p, msg in
                    Task { @MainActor [weak self] in
                        self?.update(module) { s in
                            s.progress = p
                            s.status = msg
                        }
                    }
                })
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.result = result
                        s.status = "\(result.count) éléments · \(ByteFormatter.string(result.totalSize))"
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.status = "Annulé"
                    }
                }
            }
        }
        update(module) { $0.currentTask = task }
    }

    func cancelScan(module: ModuleID) {
        moduleStates[module]?.currentTask?.cancel()
        update(module) { s in
            s.isScanning = false
            s.status = "Annulé"
        }
    }

    func clean(module: ModuleID) {
        let state = self.state(for: module)
        guard let result = state.result, !state.selection.isEmpty else { return }
        let toClean = result.items.filter { state.selection.contains($0.id) }
            .filter { ![.securityFinding, .updateAvailable, .loginItem, .launchAgent,
                        .processSnapshot, .maintenanceTask, .spaceFolder].contains($0.kind) }
        let report = Cleaner.clean(items: toClean)
        update(module) { s in
            s.lastReport = report
            s.result?.items.removeAll { item in
                state.selection.contains(item.id) && !report.failedItems.contains(item.url)
            }
            s.selection.removeAll()
            s.status = "Libéré \(ByteFormatter.string(report.freedBytes))"
        }
    }
}

struct ModuleState {
    var isScanning: Bool = false
    var progress: Double = 0
    var status: String = "Prêt"
    var result: ScanResult? = nil
    var selection: Set<UUID> = []
    var lastReport: CleanReport? = nil
    var currentTask: Task<Void, Never>? = nil
}
