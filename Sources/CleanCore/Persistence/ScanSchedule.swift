import Foundation

public enum ScheduleFrequency: String, Codable, CaseIterable, Sendable {
    case off, daily, weekly

    public var label: String {
        switch self {
        case .off: return "Désactivé"
        case .daily: return "Quotidien"
        case .weekly: return "Hebdomadaire"
        }
    }
}

public struct ScanSchedule: Codable, Equatable, Sendable {
    public var frequency: ScheduleFrequency
    public var hour: Int
    public var minute: Int
    /// launchd convention: 1 = Monday … 7 = Sunday.
    public var weekday: Int

    public init(frequency: ScheduleFrequency = .off, hour: Int = 9, minute: Int = 0, weekday: Int = 1) {
        self.frequency = frequency
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
        self.weekday = min(7, max(1, weekday))
    }
}

/// Pure generation / on-disk handling of the scheduled-scan LaunchAgent.
public enum ScheduledScanAgent {
    public static let argument = "--scheduled-scan"

    public static func label(bundleID: String) -> String { bundleID + ".scheduled-scan" }

    public static func plistURL(bundleID: String, in dir: URL? = nil) -> URL {
        let d = dir ?? FS.home.appendingPathComponent("Library/LaunchAgents")
        return d.appendingPathComponent(label(bundleID: bundleID) + ".plist")
    }

    /// XML plist content, or nil when the schedule is off.
    public static func plistData(bundleID: String, executablePath: String, schedule: ScanSchedule) -> Data? {
        guard schedule.frequency != .off else { return nil }
        var interval: [String: Int] = ["Hour": schedule.hour, "Minute": schedule.minute]
        if schedule.frequency == .weekly { interval["Weekday"] = schedule.weekday }
        let dict: [String: Any] = [
            "Label": label(bundleID: bundleID),
            "ProgramArguments": [executablePath, argument],
            "StartCalendarInterval": interval,
            "RunAtLoad": false,
            "ProcessType": "Background",
            "LowPriorityIO": true,
        ]
        return try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    /// Writes (or removes, when off) the plist. Returns the file URL when installed.
    @discardableResult
    public static func sync(bundleID: String, executablePath: String, schedule: ScanSchedule,
                            directory: URL? = nil) throws -> URL? {
        let url = plistURL(bundleID: bundleID, in: directory)
        guard let data = plistData(bundleID: bundleID, executablePath: executablePath, schedule: schedule) else {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return nil
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    public static func loadSchedule(from dir: URL = AppSupport.defaultDirectory) -> ScanSchedule {
        AppSupport.load(ScanSchedule.self, from: dir.appendingPathComponent("schedule.json")) ?? ScanSchedule()
    }

    public static func saveSchedule(_ s: ScanSchedule, to dir: URL = AppSupport.defaultDirectory) throws {
        try AppSupport.save(s, to: dir.appendingPathComponent("schedule.json"))
    }
}
