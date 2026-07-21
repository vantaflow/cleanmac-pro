import Foundation
import Darwin
import Darwin.Mach

/// Live host metrics (CPU / RAM / disk) shared by the in-window widget and the
/// real menu-bar popover. Ref-counted: the 2 s poll timer only runs while at
/// least one view is on screen, so an idle menu bar costs zero CPU (no heat).
@MainActor
final class HostStats: ObservableObject {
    @Published var cpuPct: Double = 0
    @Published var ramUsedGB: Double = 0
    @Published var ramTotalGB: Double = 0
    @Published var diskUsedGB: Double = 0
    @Published var diskTotalGB: Double = 1
    /// Rolling window of the last 32 CPU samples — drives a *real* sparkline.
    @Published private(set) var cpuHistory: [Double] = Array(repeating: 0, count: 32)

    private var timer: Timer?
    private var refCount = 0

    /// Begin observing. Call from `.onAppear`. Balanced by `stop()`.
    func start() {
        refCount += 1
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Stop observing when the last viewer disappears. Call from `.onDisappear`.
    func stop() {
        refCount = max(0, refCount - 1)
        guard refCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // RAM
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let pageBytes = Double(pageSize)
            let active = Double(vmStats.active_count) * pageBytes
            let wired  = Double(vmStats.wire_count)   * pageBytes
            let comp   = Double(vmStats.compressor_page_count) * pageBytes
            ramUsedGB = (active + wired + comp) / 1_000_000_000
        }
        var total: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &sz, nil, 0)
        ramTotalGB = Double(total) / 1_000_000_000

        // CPU — load average normalised by core count (cheap, no per-core sampling)
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        cpuPct = min(100, load[0] * 100 / Double(ProcessInfo.processInfo.activeProcessorCount))
        cpuHistory.removeFirst()
        cpuHistory.append(cpuPct)

        // Disk
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? NSNumber,
           let free = attrs[.systemFreeSize] as? NSNumber {
            diskTotalGB = total.doubleValue / 1_000_000_000
            diskUsedGB = (total.doubleValue - free.doubleValue) / 1_000_000_000
        }
    }
}
