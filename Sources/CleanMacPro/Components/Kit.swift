import SwiftUI
import AppKit
import CleanCore

/// Rounded tile with an SF Symbol, tinted with the accent of its category.
struct IconChip: View {
    var symbol: String
    var accent: Accent
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(accent.tint)
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(accent.color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Large concentric-ring badge used by the home and idle states. With a
/// `progress`, the inner ring fills while a scan runs.
struct HeroRing: View {
    @Environment(\.theme) private var theme
    var symbol: String
    var accent: Accent
    var progress: Double? = nil
    var size: CGFloat = 236
    @State private var breathe = false

    var body: some View {
        let dark = theme.dark
        ZStack {
            Circle().strokeBorder(Color.track(dark), lineWidth: 2)
            Circle()
                .strokeBorder(accent.color.opacity(0.35), lineWidth: 2)
                .padding(size * 0.076)
                .scaleEffect(breathe && progress == nil ? 1.015 : 1)
            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(accent.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.076)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
            Circle()
                .fill(Color.inset(dark))
                .overlay(Circle().strokeBorder(Color.strongBorder(dark), lineWidth: 1))
                .padding(size * 0.182)
            Image(systemName: symbol)
                .font(.system(size: size * 0.27, weight: .light))
                .foregroundColor(accent.color)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

/// Friendly empty / all-clear state.
struct EmptyState: View {
    @Environment(\.theme) private var theme
    var symbol: String = "checkmark.circle"
    var title: String
    var message: String? = nil
    var accent: Accent? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill((accent ?? theme.accent).tint).frame(width: 84, height: 84)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor((accent ?? theme.accent).color)
            }
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.text1(theme.dark))
            if let message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.text2(theme.dark))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .lineSpacing(2)
            }
            if let actionLabel, let action {
                Btn(kind: .secondary, size: .md, label: actionLabel, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

/// Inline message strip (e.g. "Libéré 4,0 Go").
struct Banner: View {
    @Environment(\.theme) private var theme
    var symbol: String
    var text: String
    var accent: Color? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent ?? theme.accent.color)
            Text(text).font(.system(size: 13)).foregroundColor(.text1(theme.dark))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .cardSurface(dark: theme.dark, radius: Radius.m, border: (accent ?? theme.accent.color).opacity(0.5))
    }
}

// MARK: — Real app / file icons

/// Resolves what a cache folder belongs to (`com.spotify.client` → Spotify, with
/// its real icon) and serves real file-type / app icons through NSWorkspace.
final class AppIdentity: @unchecked Sendable {
    static let shared = AppIdentity()

    struct Info { let name: String; let appURL: URL? }

    private let lock = NSLock()
    private var byLowerName: [String: URL] = [:]
    private var indexed = false
    private var cache: [String: Info?] = [:]
    private var icons: [String: NSImage] = [:]

    private func buildIndex() {
        guard !indexed else { return }
        indexed = true
        let fm = FileManager.default
        let roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                     "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        for r in roots {
            for e in (try? fm.contentsOfDirectory(atPath: r)) ?? [] where e.hasSuffix(".app") {
                byLowerName[String(e.dropLast(4)).lowercased()] = URL(fileURLWithPath: r + "/" + e)
            }
        }
    }

    /// App that owns a folder named `folder` (bundle id or app name), if any.
    func identify(folderName folder: String) -> Info? {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[folder] { return hit }
        buildIndex()
        var found: URL?
        if folder.contains(".") {
            var parts = folder.split(separator: ".").map(String.init)
            var tries = 0
            while found == nil, parts.count >= 3, tries < 3 {
                found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parts.joined(separator: "."))
                parts.removeLast(); tries += 1
            }
        }
        if found == nil {
            let l = folder.lowercased()
            found = byLowerName[l]
            if found == nil, l.count >= 4 {
                found = byLowerName.filter { $0.key.hasPrefix(l) }.min { $0.key.count < $1.key.count }?.value
            }
        }
        let info = found.map { Info(name: $0.deletingPathExtension().lastPathComponent, appURL: $0) }
        cache[folder] = info
        return info
    }

    func icon(forPath path: String) -> NSImage {
        lock.lock(); defer { lock.unlock() }
        if let i = icons[path] { return i }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        icons[path] = img
        return img
    }
}

/// Real icon of a file, folder or app (NSWorkspace), optionally the icon of the
/// app that owns a cache folder.
struct FileIconView: View {
    var path: String
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: AppIdentity.shared.icon(forPath: path))
            .resizable().interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension ScanItem {
    /// Name to show for the row: the owning app for a cache folder, else the file name.
    var displayName: String {
        if let t = title { return t }
        if kind.isRegenerable, fileCount != nil, let app = AppIdentity.shared.identify(folderName: url.lastPathComponent) {
            return app.name
        }
        return url.lastPathComponent
    }

    /// Path of the icon to draw: the owning app for cache folders, else the item itself.
    var iconPath: String {
        if kind.isRegenerable, fileCount != nil,
           let app = AppIdentity.shared.identify(folderName: url.lastPathComponent)?.appURL {
            return app.path
        }
        return url.path
    }

    /// `~/Library/Caches/foo` style path.
    var prettyPath: String {
        let home = NSHomeDirectory()
        let p = url.path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }
}
