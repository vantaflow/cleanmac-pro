import Foundation
import CryptoKit
#if canImport(AppKit)
import AppKit
#endif

/// Result of an in-place update attempt.
public enum SparkleInstallOutcome: Equatable {
    /// The app was replaced; carries the new marketing version.
    case installed(version: String)
    /// Automatic installation is not possible; the user must update manually (fall back to `open -a`).
    case manual(reason: String)
    /// Something went wrong; the installed app is untouched (or restored).
    case failed(reason: String)

    public var message: String {
        switch self {
        case .installed(let v): return L("Mise à jour installée (v\(v)).")
        case .manual(let r), .failed(let r): return r
        }
    }
}

/// Identity of an app bundle, read from its Info.plist.
public struct SparkleBundleInfo: Equatable {
    public let bundleID: String
    public let shortVersion: String
    public let build: String

    public init(bundleID: String, shortVersion: String, build: String) {
        self.bundleID = bundleID
        self.shortVersion = shortVersion
        self.build = build
    }

    public init?(appURL: URL) {
        guard let plist = SparkleInstaller.infoPlist(of: appURL),
              let id = plist["CFBundleIdentifier"] as? String else { return nil }
        self.init(bundleID: id,
                  shortVersion: plist["CFBundleShortVersionString"] as? String ?? "",
                  build: plist["CFBundleVersion"] as? String ?? "")
    }
}

/// Downloads a Sparkle release, verifies it, and swaps the app in /Applications.
/// Pure helpers are `static` and unit-tested; `install` does the I/O.
public enum SparkleInstaller {

    // MARK: – Pure logic

    /// Picks the app to install from an extracted archive: a top-level `.app` first
    /// (preferring one named like `preferredName`), then a one-level-deep search.
    public static func findApp(in dir: URL, preferredName: String? = nil) -> URL? {
        let fm = FileManager.default
        func apps(in d: URL) -> [URL] {
            ((try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
                .filter { $0.pathExtension == "app" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        func pick(_ list: [URL]) -> URL? {
            if let name = preferredName,
               let m = list.first(where: { $0.deletingPathExtension().lastPathComponent == name }) { return m }
            return list.first
        }
        if let top = pick(apps(in: dir)) { return top }
        let subdirs = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter { $0.pathExtension != "app" && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for sub in subdirs { if let a = pick(apps(in: sub)) { return a } }
        return nil
    }

    /// Checks the candidate bundle really is a newer version of the installed app.
    /// Returns an error message, or nil when the candidate is acceptable.
    public static func checkCandidate(installed: SparkleBundleInfo, candidate: SparkleBundleInfo) -> String? {
        guard installed.bundleID == candidate.bundleID else {
            return L("L'archive contient une autre app (\(candidate.bundleID) au lieu de \(installed.bundleID)).")
        }
        let newer: Bool
        if !installed.build.isEmpty, !candidate.build.isEmpty {
            newer = SparkleAppcast.isNewer(candidate.build, than: installed.build)
        } else {
            newer = SparkleAppcast.isNewer(candidate.shortVersion, than: installed.shortVersion)
        }
        return newer ? nil : L("La version téléchargée (v\(candidate.shortVersion)) n'est pas plus récente que v\(installed.shortVersion).")
    }

    /// Extracts `TeamIdentifier` from `codesign -dv` output. Nil when absent or "not set".
    public static func teamIdentifier(fromCodesignOutput out: String) -> String? {
        for line in out.split(whereSeparator: \.isNewline) where line.hasPrefix("TeamIdentifier=") {
            let v = line.dropFirst("TeamIdentifier=".count).trimmingCharacters(in: .whitespaces)
            return (v.isEmpty || v == "not set") ? nil : v
        }
        return nil
    }

    /// Verifies a Sparkle EdDSA signature (base64) of `data` against a base64 public key.
    public static func verifyEdDSA(data: Data, signature: String, publicKey: String) -> Bool {
        guard let sig = Data(base64Encoded: signature.trimmingCharacters(in: .whitespacesAndNewlines)),
              let key = Data(base64Encoded: publicKey.trimmingCharacters(in: .whitespacesAndNewlines)),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: key)
        else { return false }
        return pub.isValidSignature(sig, for: data)
    }

    enum ArchiveKind { case zip, dmg, pkg }

    static func archiveKind(url: URL, fileHead: Data) -> ArchiveKind? {
        switch url.pathExtension.lowercased() {
        case "zip": return .zip
        case "dmg": return .dmg
        case "pkg", "mpkg": return .pkg
        default: break
        }
        if fileHead.starts(with: [0x50, 0x4B]) { return .zip }            // "PK"
        if fileHead.starts(with: Array("xar!".utf8)) { return .pkg }
        return nil
    }

    static func infoPlist(of app: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    // MARK: – Install

    /// Installs `release` over the app at `appURL`. Never throws: failures are returned.
    public static func install(
        appURL: URL,
        release: SparkleRelease,
        applicationsDir: URL = URL(fileURLWithPath: "/Applications"),
        progress: @escaping (String) -> Void = { _ in }
    ) async -> SparkleInstallOutcome {
        let fm = FileManager.default
        let appName = appURL.deletingPathExtension().lastPathComponent
        guard let installed = SparkleBundleInfo(appURL: appURL) else {
            return .failed(reason: L("Impossible de lire l'app installée."))
        }
        guard let remote = release.downloadURL else {
            return .manual(reason: L("Le flux ne fournit pas de téléchargement : mets à jour \(appName) depuis l'app."))
        }
        guard remote.scheme == "https" else {
            return .manual(reason: L("Téléchargement non sécurisé (hors HTTPS) : mets à jour \(appName) depuis l'app."))
        }

        #if canImport(AppKit)
        if !NSRunningApplication.runningApplications(withBundleIdentifier: installed.bundleID).isEmpty {
            return .failed(reason: L("Quitte \(appName) puis réessaie."))
        }
        #endif

        let work = fm.temporaryDirectory.appendingPathComponent("cleanmac-update-\(UUID().uuidString)")
        do { try fm.createDirectory(at: work, withIntermediateDirectories: true) }
        catch { return .failed(reason: L("Dossier temporaire impossible : \(error.localizedDescription)")) }
        var mountPoint: URL?
        defer {
            if let mp = mountPoint { Shell.run("/usr/bin/hdiutil", ["detach", mp.path, "-force"], timeout: 60) }
            try? fm.removeItem(at: work)
        }

        // 1. Download
        progress(L("Téléchargement de \(appName)…"))
        let archive: URL
        do {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 30
            cfg.timeoutIntervalForResource = 600
            var req = URLRequest(url: remote)
            req.setValue("CleanMacPro/2", forHTTPHeaderField: "User-Agent")
            let (tmp, response) = try await URLSession(configuration: cfg).download(for: req)
            if let code = (response as? HTTPURLResponse)?.statusCode, code >= 400 {
                return .failed(reason: L("Téléchargement refusé (HTTP \(code))."))
            }
            let name = remote.lastPathComponent.isEmpty ? "download" : remote.lastPathComponent
            archive = work.appendingPathComponent(name)
            try fm.moveItem(at: tmp, to: archive)
        } catch {
            return .failed(reason: L("Téléchargement impossible : \(error.localizedDescription)"))
        }
        if let expected = release.length,
           let size = (try? fm.attributesOfItem(atPath: archive.path)[.size] as? NSNumber)?.int64Value,
           size != expected {
            return .failed(reason: L("Archive incomplète (\(size) octets au lieu de \(expected))."))
        }

        let head = (try? FileHandle(forReadingFrom: archive).read(upToCount: 4)) ?? Data()
        guard let kind = archiveKind(url: remote, fileHead: head) else {
            return .manual(reason: L("Format d'archive non pris en charge : mets à jour \(appName) depuis l'app."))
        }
        if kind == .pkg {
            return .manual(reason: L("\(appName) se met à jour via un installeur .pkg : installe-le manuellement."))
        }

        // 2. EdDSA (when both sides provide the material)
        let installedPlist = infoPlist(of: appURL)
        if let sig = release.edSignature, let key = installedPlist?["SUPublicEDKey"] as? String {
            progress(L("Vérification de la signature EdDSA…"))
            guard let data = try? Data(contentsOf: archive, options: .mappedIfSafe),
                  verifyEdDSA(data: data, signature: sig, publicKey: key) else {
                return .failed(reason: L("Signature EdDSA invalide : mise à jour refusée."))
            }
        }

        // 3. Extract
        progress(L("Extraction…"))
        let extracted = work.appendingPathComponent("extracted")
        try? fm.createDirectory(at: extracted, withIntermediateDirectories: true)
        let searchRoot: URL
        switch kind {
        case .zip:
            let r = Shell.run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path], timeout: 300)
            guard r.status == 0 else { return .failed(reason: L("Extraction impossible : \(String(r.stderr.prefix(120)))")) }
            searchRoot = extracted
        case .dmg:
            let mp = work.appendingPathComponent("mnt")
            try? fm.createDirectory(at: mp, withIntermediateDirectories: true)
            let r = Shell.run("/usr/bin/hdiutil",
                              ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mp.path, archive.path],
                              timeout: 300)
            guard r.status == 0 else { return .failed(reason: L("Montage du .dmg impossible : \(String(r.stderr.prefix(120)))")) }
            mountPoint = mp
            searchRoot = mp
        case .pkg:
            return .manual(reason: L("Installe \(appName) manuellement."))
        }
        guard let newApp = findApp(in: searchRoot, preferredName: appName) else {
            return .failed(reason: L("Aucune app trouvée dans l'archive."))
        }

        // 4. Verify candidate. For a dmg, copy out of the mount first so it survives detach.
        progress(L("Vérification…"))
        let staged = work.appendingPathComponent("staged").appendingPathComponent(newApp.lastPathComponent)
        try? fm.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        let cp = Shell.run("/usr/bin/ditto", [newApp.path, staged.path], timeout: 300)
        guard cp.status == 0 else { return .failed(reason: L("Copie impossible : \(String(cp.stderr.prefix(120)))")) }

        guard let candidate = SparkleBundleInfo(appURL: staged) else {
            return .failed(reason: L("L'app téléchargée est illisible."))
        }
        if let err = checkCandidate(installed: installed, candidate: candidate) { return .failed(reason: err) }

        let verify = Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path], timeout: 120)
        guard verify.status == 0 else {
            return .failed(reason: L("Signature de code invalide : \(String(verify.stderr.prefix(120)))"))
        }
        let oldTeam = teamIdentifier(fromCodesignOutput: Shell.run("/usr/bin/codesign", ["-dv", appURL.path]).stderr)
        if let oldTeam {
            let newTeam = teamIdentifier(fromCodesignOutput: Shell.run("/usr/bin/codesign", ["-dv", staged.path]).stderr)
            guard newTeam == oldTeam else {
                return .failed(reason: L("Le développeur de la mise à jour diffère de celui de l'app installée."))
            }
        }

        // 5. Swap: old app to the Trash, new app into Applications, restore on failure.
        progress(L("Remplacement de \(appName)…"))
        #if canImport(AppKit)
        if !NSRunningApplication.runningApplications(withBundleIdentifier: installed.bundleID).isEmpty {
            return .failed(reason: L("Quitte \(appName) puis réessaie."))
        }
        #endif
        let destination = applicationsDir.appendingPathComponent(appURL.lastPathComponent)
        var trashed: NSURL?
        do {
            try fm.trashItem(at: appURL, resultingItemURL: &trashed)
        } catch {
            return .manual(reason: L("Impossible de déplacer \(appName) à la Corbeille (\(error.localizedDescription)) : mets à jour depuis l'app."))
        }
        let place = Shell.run("/usr/bin/ditto", [staged.path, destination.path], timeout: 300)
        if place.status != 0 {
            try? fm.removeItem(at: destination)
            if let t = trashed as URL?, (try? fm.moveItem(at: t, to: appURL)) != nil {
                return .failed(reason: L("Copie dans \(applicationsDir.path) impossible, ancienne version restaurée : \(String(place.stderr.prefix(120)))"))
            }
            return .failed(reason: L("Copie impossible et restauration échouée : récupère \(appName) dans la Corbeille."))
        }
        return .installed(version: candidate.shortVersion.isEmpty ? candidate.build : candidate.shortVersion)
    }
}
