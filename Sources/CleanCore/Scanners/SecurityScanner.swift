import Foundation

/// Reports real macOS security posture: FileVault, Gatekeeper, XProtect, SIP,
/// Firewall, and a quick scan of well-known adware/malware persistence paths.
public struct SecurityScanner: FileScanner {
    public let module: ModuleID = .security

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []

        progress(0.05, "FileVault…")
        items.append(filevaultCheck())

        progress(0.15, "Gatekeeper…")
        items.append(gatekeeperCheck())

        progress(0.30, "SIP…")
        items.append(sipCheck())

        progress(0.45, L("Pare-feu…"))
        items.append(firewallCheck())

        progress(0.55, "XProtect…")
        items.append(xprotectCheck())

        progress(0.70, L("Recherche de menaces connues…"))
        items.append(contentsOf: knownThreats())

        progress(1.0, L("Done"))
        return ScanResult(module: .security, items: items)
    }

    private func filevaultCheck() -> ScanItem {
        let (_, out, _) = Shell.run("/usr/bin/fdesetup", ["isactive"])
        let enabled = out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        return ScanItem(
            url: URL(fileURLWithPath: "/System/FileVault"),
            size: 0,
            kind: .securityFinding,
            group: L("Système"),
            title: "FileVault",
            detail: enabled ? L("Activé — disque chiffré") : L("Désactivé — disque non chiffré"),
            severity: enabled ? .good : .bad
        )
    }

    private func gatekeeperCheck() -> ScanItem {
        let (_, out, _) = Shell.run("/usr/sbin/spctl", ["--status"])
        let enabled = out.contains("assessments enabled")
        return ScanItem(
            url: URL(fileURLWithPath: "/System/Gatekeeper"),
            size: 0,
            kind: .securityFinding,
            group: L("Système"),
            title: "Gatekeeper",
            detail: enabled ? L("Activé — apps signées vérifiées") : L("Désactivé"),
            severity: enabled ? .good : .warn
        )
    }

    private func sipCheck() -> ScanItem {
        let (_, out, _) = Shell.run("/usr/bin/csrutil", ["status"])
        let enabled = out.contains("enabled")
        return ScanItem(
            url: URL(fileURLWithPath: "/System/SIP"),
            size: 0,
            kind: .securityFinding,
            group: L("Système"),
            title: "System Integrity Protection",
            detail: enabled ? L("Activé") : L("Désactivé — protections systèmes affaiblies"),
            severity: enabled ? .good : .bad
        )
    }

    private func firewallCheck() -> ScanItem {
        let (_, out, _) = Shell.run(
            "/usr/libexec/ApplicationFirewall/socketfilterfw",
            ["--getglobalstate"]
        )
        let enabled = out.contains("enabled")
        return ScanItem(
            url: URL(fileURLWithPath: "/System/Firewall"),
            size: 0,
            kind: .securityFinding,
            group: L("Système"),
            title: L("Pare-feu"),
            detail: enabled ? L("Activé") : L("Désactivé"),
            severity: enabled ? .good : .warn
        )
    }

    private func xprotectCheck() -> ScanItem {
        let path = "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
        let exists = FileManager.default.fileExists(atPath: path)
        var version = L("inconnue")
        if exists,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let v = plist["CFBundleShortVersionString"] as? String {
            version = v
        }
        return ScanItem(
            url: URL(fileURLWithPath: path),
            size: 0,
            kind: .securityFinding,
            group: L("Système"),
            title: "XProtect",
            detail: exists ? L("Actif · version \(version)") : L("Introuvable"),
            severity: exists ? .good : .warn
        )
    }

    /// Scans well-known launch paths for entries matching adware/malware names
    /// publicly tracked by Apple's malware-removal tool. This is best-effort.
    private func knownThreats() -> [ScanItem] {
        let suspectNames: Set<String> = [
            "MacKeeper", "Genieo", "Conduit", "Vsearch", "InstallMac",
            "Mughthesec", "FkCodec", "Spigot", "Crossrider", "Bundlore"
        ]
        let roots: [URL] = [
            FS.home.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]
        var found: [ScanItem] = []
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries {
                let lower = entry.lastPathComponent.lowercased()
                if suspectNames.contains(where: { lower.contains($0.lowercased()) }) {
                    found.append(ScanItem(
                        url: entry,
                        size: FS.size(of: entry),
                        kind: .securityFinding,
                        group: L("Menaces"),
                        title: entry.lastPathComponent,
                        detail: L("Persistance suspecte dans \(root.lastPathComponent)"),
                        severity: .bad
                    ))
                }
            }
        }
        if found.isEmpty {
            found.append(ScanItem(
                url: URL(fileURLWithPath: "/"),
                size: 0,
                kind: .securityFinding,
                group: L("Menaces"),
                title: L("Aucune menace connue détectée"),
                detail: L("Les chemins LaunchAgents/LaunchDaemons sont propres"),
                severity: .good
            ))
        }
        return found
    }
}
