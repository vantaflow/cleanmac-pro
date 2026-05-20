import SwiftUI
import CleanCore

struct AppToolbar: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            Text(appState.active.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.text1(theme.dark))
            Spacer()
            // search-like chip
            HStack(spacing: 6) {
                CmpIcon(name: "search", size: 12, color: .text3(theme.dark))
                Text("Rechercher").font(.system(size: 12)).foregroundColor(.text3(theme.dark))
                Spacer()
                Text("⌘F")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(.text3(theme.dark))
            }
            .padding(.horizontal, 10)
            .frame(width: 200, height: 26)
            .background(Color.black.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.hairline(theme.dark), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            ToolbarChip(icon: "chip", active: appState.menubarOpen) {
                appState.menubarOpen.toggle()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairlineSoft(theme.dark)).frame(height: 0.5)
        }
    }
}

private struct ToolbarChip: View {
    @Environment(\.theme) private var theme
    let icon: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            CmpIcon(name: icon, size: 14,
                    color: active ? theme.accent.onAccent : .text2(theme.dark))
                .frame(width: 26, height: 26)
                .background(active ? AnyShapeStyle(theme.accent.color) : AnyShapeStyle(Color.black.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.hairline(theme.dark), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
