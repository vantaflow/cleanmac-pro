import Foundation
import SwiftUI
import CleanCore

@MainActor
final class AppState: ObservableObject {
    @Published var selectedModule: ModuleID? = .smartScan
    @Published var moduleStates: [ModuleID: ModuleState] = [:]

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

    func scanner(for module: ModuleID) -> any FileScanner {
        switch module {
        case .smartScan:   return SmartScanner()
        case .largeFiles:  return LargeFilesScanner()
        case .uninstaller: return AppUninstaller()
        case .duplicates:  return DuplicatesScanner()
        }
    }

    func startScan(module: ModuleID) {
        update(module) { s in
            s.isScanning = true
            s.progress = 0
            s.status = "Starting…"
            s.result = nil
            s.selection.removeAll()
        }

        let scanner = scanner(for: module)
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
                        s.status = "Found \(result.count) items · \(ByteFormatter.string(result.totalSize))"
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.status = "Scan cancelled"
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
            s.status = "Cancelled"
        }
    }

    func clean(module: ModuleID) {
        let state = self.state(for: module)
        guard let result = state.result, !state.selection.isEmpty else { return }
        let toClean = result.items.filter { state.selection.contains($0.id) }
        let report = Cleaner.clean(items: toClean)
        update(module) { s in
            s.lastReport = report
            s.result?.items.removeAll { report.failedItems.contains($0.url) == false && state.selection.contains($0.id) }
            s.selection.removeAll()
            s.status = "Freed \(ByteFormatter.string(report.freedBytes))"
        }
    }
}

struct ModuleState {
    var isScanning: Bool = false
    var progress: Double = 0
    var status: String = "Ready"
    var result: ScanResult? = nil
    var selection: Set<UUID> = []
    var lastReport: CleanReport? = nil
    var currentTask: Task<Void, Never>? = nil
}
