import Foundation
#if canImport(ApplicationServices)
import ApplicationServices
#endif

/// macOS privacy permissions CleanMac Pro cares about.
public enum PermissionKind: String, CaseIterable, Sendable {
    case fullDiskAccess, notifications, automation

    /// Deep link to the matching System Settings pane.
    public var settingsURL: URL {
        switch self {
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        case .notifications:
            return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        case .automation:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        }
    }
}

public enum PermissionStatus: String, Sendable, Equatable {
    case granted
    case denied
    /// The user was never asked (or the state can't be told without prompting).
    case notDetermined
}

/// Testable detection logic. Every system access is injected.
public struct PermissionDetector: Sendable {
    /// TCC-protected files/folders. Reading one of them succeeds only with Full Disk Access.
    public static func defaultFullDiskProbes(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [home.appendingPathComponent("Library/Safari/Bookmarks.plist"),
         home.appendingPathComponent("Library/Safari/CloudTabs.db"),
         home.appendingPathComponent("Library/Mail"),
         home.appendingPathComponent("Library/Messages")]
    }

    public enum ReadOutcome: Sendable, Equatable {
        case readable, denied, missing
    }

    /// Tries to read the item. Never shows a prompt: reading Safari/Mail data
    /// simply fails with EPERM when Full Disk Access is not granted.
    public static func systemRead(_ url: URL) -> ReadOutcome {
        var isDir: ObjCBool = false
        if url.hasDirectoryPath || (FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue) {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                return .readable
            } catch { return classify(error) }
        }
        do {
            let h = try FileHandle(forReadingFrom: url)
            try? h.close()
            return .readable
        } catch { return classify(error) }
    }

    static func classify(_ error: Error) -> ReadOutcome {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            if ns.code == NSFileReadNoSuchFileError || ns.code == NSFileNoSuchFileError { return .missing }
            if ns.code == NSFileReadNoPermissionError { return .denied }
        }
        if let u = ns.userInfo[NSUnderlyingErrorKey] as? NSError, u.domain == NSPOSIXErrorDomain {
            if u.code == Int(ENOENT) { return .missing }
            if u.code == Int(EPERM) || u.code == Int(EACCES) { return .denied }
        }
        if ns.domain == NSPOSIXErrorDomain {
            if ns.code == Int(ENOENT) { return .missing }
            if ns.code == Int(EPERM) || ns.code == Int(EACCES) { return .denied }
        }
        return .denied
    }

    /// Full Disk Access: granted if any probe is readable; denied if at least one
    /// existing probe was refused and none was readable; otherwise undetermined
    /// (none of the probes exists on this machine).
    public static func fullDiskAccess(probes: [URL] = defaultFullDiskProbes(),
                                      read: (URL) -> ReadOutcome = systemRead) -> PermissionStatus {
        var denied = false
        for p in probes {
            switch read(p) {
            case .readable: return .granted
            case .denied: denied = true
            case .missing: continue
            }
        }
        return denied ? .denied : .notDetermined
    }

    /// Maps UNAuthorizationStatus raw values (0 notDetermined, 1 denied, 2 authorized,
    /// 3 provisional, 4 ephemeral) so the mapping is testable without UserNotifications.
    public static func notifications(rawAuthorizationStatus raw: Int) -> PermissionStatus {
        switch raw {
        case 1: return .denied
        case 2, 3, 4: return .granted
        default: return .notDetermined
        }
    }

    /// Maps an OSStatus from AEDeterminePermissionToAutomateTarget.
    /// noErr granted, errAEEventNotPermitted (-1743) denied, errAEEventWouldRequireUserConsent (-1744)
    /// not asked yet, procNotFound (-600) target not running (cannot tell without launching it).
    public static func automation(osStatus: Int32) -> PermissionStatus {
        switch osStatus {
        case 0: return .granted
        case -1743: return .denied
        default: return .notDetermined
        }
    }

    public static let systemEventsBundleID = "com.apple.systemevents"

    #if canImport(ApplicationServices)
    /// Asks TCC about automation of System Events. With `prompt: false` it never
    /// shows the consent dialog. If System Events isn't running, the answer is
    /// `.notDetermined` (it is launched on demand when `prompt` is true).
    public static func automationStatus(prompt: Bool) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: systemEventsBundleID)
        guard let desc = target.aeDesc else { return .notDetermined }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, prompt)
        return automation(osStatus: Int32(status))
    }
    #endif
}

/// Modules that can't see everything without Full Disk Access.
public enum PermissionNeeds {
    public static func needsFullDiskAccess(_ module: ModuleID) -> Bool {
        [.privacy, .cleanup, .files, .similarPhotos].contains(module)
    }
}
