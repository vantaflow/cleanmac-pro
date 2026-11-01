import SwiftUI
import CleanCore

struct SortMenu: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID

    var body: some View {
        let state = appState.state(for: module)
        Menu {
            ForEach(SortKey.allCases) { key in
                Button {
                    appState.update(module) { s in
                        if s.sortKey == key { s.sortDescending.toggle() }
                        else { s.sortKey = key; s.sortDescending = (key != .name) }
                    }
                } label: {
                    HStack {
                        Text(key.label)
                        if state.sortKey == key {
                            Image(systemName: state.sortDescending ? "arrow.down" : "arrow.up")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(L("Trier"))
                    .foregroundColor(.text2(theme.dark))
                Text(state.sortKey.label)
                    .foregroundColor(.text1(theme.dark))
                Image(systemName: state.sortDescending ? "arrow.down" : "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.text2(theme.dark))
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14).frame(height: 36)
            .background(Capsule().fill(Color.inset(theme.dark)))
            .capsuleBorder(Color.cardBorder(theme.dark), lineWidth: 1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
